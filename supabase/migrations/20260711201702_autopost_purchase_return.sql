-- M07 A5 hook: create_purchase_return auto-posts a balanced PURCHASE_RETURN journal.
-- Reverses Hook 2 (perpetual): Dr 2000 AP (total) / Cr 1200 Inventory (subtotal) / Cr 1300 Input Tax (tax).
-- 5100 Purchase Returns stays unused (periodic-only). Dr AP always; cash refund is a separate event.
-- Ungated (p_gate=false). Body verbatim from live def; only v_lines decl + GL block are new.
CREATE OR REPLACE FUNCTION public.create_purchase_return(p_branch_id uuid, p_po_id uuid, p_grn_id uuid, p_invoice_id uuid, p_reason text, p_notes text, p_items jsonb, p_reduce_invoice boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_supplier uuid; v_po_branch uuid; v_ret_id uuid; v_num text;
  v_item jsonb; v_po_item purchase_order_items%rowtype;
  v_qty numeric; v_already numeric; v_avail numeric;
  v_line numeric; v_line_tax numeric; v_landed_unit numeric; v_cost_unit numeric;
  v_subtotal numeric := 0; v_tax_total numeric := 0; v_total numeric;
  v_imei text; v_imei_count int; v_lines jsonb; v_cogs_basis numeric := 0;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not public.auth_has_branch(p_branch_id) then raise exception 'ERR_BRANCH_NOT_ASSIGNED' using errcode='42501'; end if;

  select supplier_id, branch_id into v_supplier, v_po_branch
    from purchase_orders where id=p_po_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_PO_NOT_FOUND'; end if;
  if p_grn_id is not null and not exists (select 1 from grns where id=p_grn_id and po_id=p_po_id and tenant_id=v_t) then
    raise exception 'ERR_GRN_MISMATCH'; end if;
  if p_invoice_id is not null and not exists (select 1 from purchase_invoices where id=p_invoice_id and po_id=p_po_id and tenant_id=v_t and deleted_at is null) then
    raise exception 'ERR_INVOICE_MISMATCH'; end if;
  if p_items is null or jsonb_array_length(p_items)=0 then raise exception 'ERR_NO_ITEMS'; end if;

  v_num := public.next_number('PURCHASE_RETURN', p_branch_id);

  insert into purchase_returns (tenant_id, branch_id, supplier_id, po_id, grn_id, invoice_id,
    return_number, status, reason, notes, created_by, updated_by)
  values (v_t, p_branch_id, v_supplier, p_po_id, p_grn_id, p_invoice_id, v_num, 'CONFIRMED',
    p_reason, p_notes, v_uid, v_uid)
  returning id into v_ret_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_po_item from purchase_order_items
      where id=(v_item->>'po_item_id')::uuid and po_id=p_po_id;
    if not found then raise exception 'ERR_PO_ITEM_NOT_FOUND'; end if;

    v_qty := (v_item->>'qty_returned')::numeric;
    if v_qty is null or v_qty <= 0 then raise exception 'ERR_BAD_QTY'; end if;

    -- available = received − prior CONFIRMED returns for this po_item
    select coalesce(sum(pri.qty_returned),0) into v_already
      from purchase_return_items pri
      join purchase_returns pr on pr.id=pri.return_id
      where pri.po_item_id=v_po_item.id and pr.status='CONFIRMED' and pr.deleted_at is null;
    v_avail := v_po_item.qty_received - v_already;
    if v_qty > v_avail then raise exception 'ERR_RETURN_EXCEEDS_RECEIVED'; end if;

    -- IMEI: if serials supplied, count must equal qty; they must be currently sellable + this product
    if (v_item ? 'imei_ids') and jsonb_typeof(v_item->'imei_ids')='array' then
      v_imei_count := jsonb_array_length(v_item->'imei_ids');
      if v_imei_count <> v_qty then raise exception 'ERR_IMEI_COUNT_MISMATCH'; end if;
      for v_imei in select jsonb_array_elements_text(v_item->'imei_ids') loop
        update imei_records
          set status = 'RETURNED'::imei_status_enum,   -- <<< R0.4 confirm this label >>>
              updated_at = now(), version = version + 1
          where tenant_id=v_t and product_id=v_po_item.product_id and imei=trim(v_imei);
        if not found then raise exception 'ERR_IMEI_NOT_FOUND'; end if;
      end loop;
    end if;

    v_line := round(v_qty * v_po_item.unit_cost, 4);
    v_line_tax := round(v_line * v_po_item.tax_pct/100.0, 4);
    v_subtotal := v_subtotal + v_line;
    v_tax_total := v_tax_total + v_line_tax;

    insert into purchase_return_items (return_id, po_item_id, product_id, variant_id, qty_returned,
      unit_cost, tax_pct, line_total, imei_ids_json)
    values (v_ret_id, v_po_item.id, v_po_item.product_id, v_po_item.variant_id, v_qty,
      v_po_item.unit_cost, v_po_item.tax_pct, v_line, v_item->'imei_ids');

    -- reverse stock: canonical NULL warehouse, RETURN_OUT, NEGATIVE qty, at landed unit cost
    v_landed_unit := case when v_po_item.qty_ordered > 0
      then v_po_item.landed_cost_allocated / v_po_item.qty_ordered else 0 end;
    v_cost_unit := round(v_po_item.unit_cost_base + v_landed_unit, 4);
    v_cogs_basis := v_cogs_basis + round(v_cost_unit * v_qty, 4);   -- GL inventory basis = exactly what stock removes
    perform public.post_stock_movement(
      p_branch_id, null, v_po_item.product_id, v_po_item.variant_id,
      'RETURN_OUT'::stock_movement_type_enum, -v_qty, v_cost_unit,
      'PURCHASE_RETURN', v_ret_id, 'Return '||v_num);
  end loop;

  v_total := round(v_subtotal + v_tax_total, 4);
  update purchase_returns set subtotal=round(v_subtotal,4), tax_total=round(v_tax_total,4),
    total_amount=v_total, updated_at=now() where id=v_ret_id;

  -- OPT-IN only: reduce a linked invoice's outstanding balance (true debit-note-against-bill)
  if p_reduce_invoice and p_invoice_id is not null then
    update purchase_invoices
      set balance = greatest(0, balance - v_total), updated_at = now(), version = version + 1
      where id = p_invoice_id;
  end if;

  -- ===== M07 A5: auto-post purchase return to GL (ungated; reverses the purchase-invoice posting) =====
  -- Perpetual model: credit Inventory (goods leave) at the SAME cost basis the stock reversal removed
  -- (v_cogs_basis = Σ v_cost_unit·qty = unit_cost_base + landed), NOT v_subtotal (Σ qty·unit_cost) — the two
  -- diverge once landed cost or FX≠1 exists, which would silently drift inventory-on-books from stock.
  -- Dr AP always (a cash refund is a separate supplier-payment event; the RPC has no refund flag). 5100 unused.
  if v_cogs_basis > 0 or round(v_tax_total,4) > 0 then
    v_lines := jsonb_build_array(jsonb_build_object('account_code','2000','debit', round(v_cogs_basis + v_tax_total, 4)));
    if v_cogs_basis > 0 then v_lines := v_lines || jsonb_build_object('account_code','1200','credit', round(v_cogs_basis,4)); end if;
    if round(v_tax_total,4) > 0 then v_lines := v_lines || jsonb_build_object('account_code','1300','credit', round(v_tax_total,4)); end if;
    perform public.post_journal(p_branch_id, 'PURCHASE_RETURN', v_ret_id, 'Purchase return '||v_num, v_lines, current_date, null, false);
  end if;

  return jsonb_build_object('return_id', v_ret_id, 'return_number', v_num, 'total_amount', v_total);
end; $function$

;
