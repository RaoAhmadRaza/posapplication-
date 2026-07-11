-- <ts>_void_invoice.sql — reverse a sale: restock each line (RETURN_IN), restore IMEI, set status VOID.
-- Gated on sales:delete. Atomic. Cannot void an already RETURNED/VOID invoice.
create or replace function public.void_invoice(p_invoice_id uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid(); v_inv invoices%rowtype; r record;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('sales','delete') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select * into v_inv from invoices where id=p_invoice_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_INVOICE_NOT_FOUND'; end if;
  if v_inv.status in ('VOID','RETURNED') then raise exception 'ERR_ALREADY_VOID_OR_RETURNED'; end if;

  for r in select product_id, variant_id, imei_id, qty, cost_price from invoice_items where invoice_id=p_invoice_id loop
    perform public.post_stock_movement(
      v_inv.branch_id, null, r.product_id, r.variant_id, 'RETURN_IN', r.qty, r.cost_price, 'VOID', p_invoice_id, 'void sale');
    if r.imei_id is not null then
      update imei_records set status='AVAILABLE', sold_invoice_id=null where id=r.imei_id and tenant_id=v_t;
    end if;
  end loop;

  update invoices set status='VOID', return_reason=p_reason, updated_at=now(), updated_by=v_uid
   where id=p_invoice_id;   -- immutability trigger allows →VOID
  return jsonb_build_object('invoice_id',p_invoice_id,'status','VOID');
end; $$;
revoke all on function public.void_invoice(uuid,text) from anon, public;
grant execute on function public.void_invoice(uuid,text) to authenticated;