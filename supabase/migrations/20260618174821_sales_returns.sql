-- <timestamp>_sales_returns.sql
-- create_sales_return: validate qty vs sold (minus prior returns), restock via post_stock_movement RETURN_IN,
-- record refund, link original_invoice_id, set RETURNED. Atomic + permission-gated on sales:update
-- (existing action — ADMIN has it, CASHIER does not, so returns are manager-gated. S0-D2 confirmed action set.)
create or replace function public.create_sales_return(
  p_original_invoice_id uuid,
  p_items jsonb,        -- [{invoice_item_id, qty}]
  p_reason text,
  p_refund jsonb default '[]'  -- [{method, amount, reference?}]
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_orig invoices%rowtype; v_ret uuid := gen_random_uuid(); v_number varchar; r jsonb;
  v_iid uuid; v_qty numeric; v_item invoice_items%rowtype; v_prior numeric; v_line numeric;
  v_grand numeric := 0; v_refund numeric := 0; v_imei uuid;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('sales','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select * into v_orig from invoices where id=p_original_invoice_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_INVOICE_NOT_FOUND'; end if;
  if p_items is null or jsonb_array_length(p_items)=0 then raise exception 'ERR_EMPTY_RETURN'; end if;

  v_number := public.next_number('INVOICE'::number_series_type_enum, v_orig.branch_id);
  insert into invoices (id, tenant_id, branch_id, invoice_number, customer_id, cashier_id, session_id,
                        status, sale_type, original_invoice_id, return_reason, created_by, updated_by)
  values (v_ret, v_t, v_orig.branch_id, v_number, v_orig.customer_id, v_uid, v_orig.session_id,
          'DRAFT', v_orig.sale_type, p_original_invoice_id, p_reason, v_uid, v_uid);

  for r in select * from jsonb_array_elements(p_items) loop
    v_iid := (r->>'invoice_item_id')::uuid;
    v_qty := coalesce((r->>'qty')::numeric, 0);
    if v_qty <= 0 then raise exception 'ERR_INVALID_QTY'; end if;
    select * into v_item from invoice_items where id=v_iid and invoice_id=p_original_invoice_id;
    if not found then raise exception 'ERR_ITEM_NOT_IN_INVOICE: %', v_iid; end if;
    -- prior returns for this original line
    select coalesce(sum(ii.qty),0) into v_prior from invoice_items ii
      join invoices i on i.id=ii.invoice_id
      where i.original_invoice_id=p_original_invoice_id and ii.product_id=v_item.product_id;
    if v_qty > (v_item.qty - v_prior) then raise exception 'ERR_RETURN_EXCEEDS_SOLD: %', v_iid; end if;

    v_line := round(v_qty * v_item.unit_price * (1 - v_item.discount_pct/100.0), 4);
    insert into invoice_items (invoice_id, product_id, variant_id, imei_id, description, qty, unit_price,
                              cost_price, discount_pct, discount_amount, tax_pct, tax_amount, line_total, profit)
    values (v_ret, v_item.product_id, v_item.variant_id, v_item.imei_id, v_item.description, v_qty,
            v_item.unit_price, v_item.cost_price, v_item.discount_pct, 0, v_item.tax_pct, 0, v_line, 0);
    v_grand := v_grand + v_line;

    -- restock (positive RETURN_IN). S0-B1: ARG4 = p_variant_id (pass the line's variant, not imei).
    perform public.post_stock_movement(
      v_orig.branch_id, null, v_item.product_id, v_item.variant_id, 'RETURN_IN', v_qty, v_item.cost_price,
      'RETURN', v_ret, 'sales return');
    if v_item.imei_id is not null then
      update imei_records set status='AVAILABLE', sold_invoice_id=null
        where id=v_item.imei_id and tenant_id=v_t;
    end if;
  end loop;

  -- refund payments (recorded as negative? keep positive rows tagged to the return invoice)
  if p_refund is not null then
    for r in select * from jsonb_array_elements(p_refund) loop
      if coalesce((r->>'amount')::numeric,0) <= 0 then continue; end if;
      insert into payments (tenant_id, invoice_id, method, amount, reference, created_by)
      values (v_t, v_ret, (r->>'method')::payment_method_enum, (r->>'amount')::numeric, nullif(r->>'reference',''), v_uid);
      v_refund := v_refund + (r->>'amount')::numeric;
    end loop;
  end if;

  update invoices set status='RETURNED', grand_total=v_grand, paid_amount=v_refund, balance=v_grand - v_refund,
    updated_at=now(), updated_by=v_uid where id=v_ret;
  -- mark original RETURNED when fully returned
  update invoices set status='RETURNED', updated_at=now()
    where id=p_original_invoice_id
      and not exists (
        select 1 from invoice_items oi
        where oi.invoice_id=p_original_invoice_id
          and oi.qty > (select coalesce(sum(ri.qty),0) from invoice_items ri
                        join invoices r2 on r2.id=ri.invoice_id
                        where r2.original_invoice_id=p_original_invoice_id and ri.product_id=oi.product_id));

  return jsonb_build_object('return_invoice_id',v_ret,'invoice_number',v_number,'grand_total',v_grand,'refunded',v_refund);
end; $$;
revoke all on function public.create_sales_return(uuid,jsonb,text,jsonb) from anon, public;
grant execute on function public.create_sales_return(uuid,jsonb,text,jsonb) to authenticated;