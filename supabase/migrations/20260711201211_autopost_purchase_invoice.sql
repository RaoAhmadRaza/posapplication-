-- M07 A5 hook: create_purchase_invoice auto-posts a balanced PURCHASE_INVOICE journal.
-- Dr 1200 Inventory (amount) + Dr 1300 Input Tax (tax) / Cr 2000 AP (total). Inventory books
-- at invoice time (GRN posts no GL). Ungated system post (p_gate=false). Body verbatim from the
-- live def; only additions: fetch po.branch_id (post_journal needs a branch) + the GL block.
CREATE OR REPLACE FUNCTION public.create_purchase_invoice(p_po_id uuid, p_grn_id uuid, p_supplier_invoice_number character varying, p_amount numeric, p_tax_amount numeric, p_due_date date, p_notes text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_supplier uuid; v_po_total numeric; v_total numeric; v_inv_id uuid; v_variance numeric;
  v_branch uuid; v_lines jsonb := '[]'::jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select supplier_id, grand_total, branch_id into v_supplier, v_po_total, v_branch
    from purchase_orders where id=p_po_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_PO_NOT_FOUND'; end if;
  if p_grn_id is not null and not exists (select 1 from grns where id=p_grn_id and po_id=p_po_id and tenant_id=v_t) then
    raise exception 'ERR_GRN_MISMATCH';    -- GRN must belong to this PO
  end if;
  if p_amount is null or p_amount < 0 then raise exception 'ERR_BAD_AMOUNT'; end if;

  v_total := round(coalesce(p_amount,0) + coalesce(p_tax_amount,0), 4);
  v_variance := round(v_total - coalesce(v_po_total,0), 4);   -- 3-way match variance (informational)

  insert into purchase_invoices (tenant_id, po_id, grn_id, supplier_id, supplier_invoice_number,
    amount, tax_amount, total_amount, paid_amount, balance, status, due_date, notes, created_by, updated_by)
  values (v_t, p_po_id, p_grn_id, v_supplier, nullif(p_supplier_invoice_number,''),
    round(coalesce(p_amount,0),4), round(coalesce(p_tax_amount,0),4), v_total, 0, v_total,
    'PENDING', p_due_date, p_notes, v_uid, v_uid)
  returning id into v_inv_id;

  update purchase_orders set status='INVOICED', updated_at=now(), version=version+1
    where id=p_po_id and status in ('RECEIVED','PARTIALLY_RECEIVED');

  -- ===== M07 A5: auto-post purchase invoice to GL (ungated; mirrors AP subledger) =====
  if round(coalesce(p_amount,0),4)     > 0 then v_lines := v_lines || jsonb_build_object('account_code','1200','debit',  round(coalesce(p_amount,0),4)); end if;
  if round(coalesce(p_tax_amount,0),4) > 0 then v_lines := v_lines || jsonb_build_object('account_code','1300','debit',  round(coalesce(p_tax_amount,0),4)); end if;
  if v_total > 0 then v_lines := v_lines || jsonb_build_object('account_code','2000','credit', v_total); end if;
  if jsonb_array_length(v_lines) >= 2 then
    perform public.post_journal(v_branch, 'PURCHASE_INVOICE', v_inv_id, 'Purchase invoice', v_lines, current_date, v_inv_id, false);
  end if;

  return jsonb_build_object('invoice_id', v_inv_id, 'total_amount', v_total, 'match_variance', v_variance);
end; $function$;
