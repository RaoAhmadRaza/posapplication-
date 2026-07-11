-- Supplier ledger: invoices (debits/payable increases) + payments (credits) with running balance.
create or replace function public.supplier_ledger(p_supplier_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_opening numeric; v_result jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','read') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select opening_balance into v_opening from suppliers where id=p_supplier_id and tenant_id=v_t;
  if not found then raise exception 'ERR_SUPPLIER_NOT_FOUND'; end if;

  with entries as (
    select pi.created_at as ts, 'INVOICE' as kind, pi.total_amount as debit, 0::numeric as credit,
           pi.supplier_invoice_number as ref, pi.status::text as status
    from purchase_invoices pi where pi.supplier_id=p_supplier_id and pi.tenant_id=v_t and pi.deleted_at is null
    union all
    select sp.paid_at, 'PAYMENT', 0, sp.amount, sp.voucher_number, sp.method::text
    from supplier_payments sp where sp.supplier_id=p_supplier_id and sp.tenant_id=v_t
  ), ordered as (
    select *, sum(debit - credit) over (order by ts, kind rows between unbounded preceding and current row) as running
    from entries
  )
  select jsonb_build_object(
    'supplier_id', p_supplier_id,
    'opening_balance', coalesce(v_opening,0),
    'current_balance', coalesce(v_opening,0) + coalesce((select sum(debit-credit) from entries),0),
    'entries', coalesce((select jsonb_agg(jsonb_build_object(
        'ts',ts,'kind',kind,'debit',debit,'credit',credit,'reference',ref,'status',status,
        'running_balance', coalesce(v_opening,0) + running) order by ts, kind) from ordered), '[]'::jsonb)
  ) into v_result;
  return v_result;
end; $function$;

-- Payables aging: open invoice balances bucketed by due_date age (schema §8.5).
create or replace function public.payables_aging()
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_result jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','read') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  with open_inv as (
    select pi.supplier_id, s.name as supplier_name, pi.balance,
      greatest(0, (current_date - coalesce(pi.due_date, pi.created_at::date))) as days_overdue
    from purchase_invoices pi join suppliers s on s.id=pi.supplier_id
    where pi.tenant_id=v_t and pi.deleted_at is null and pi.balance > 0 and pi.status <> 'VOID'
  )
  select jsonb_build_object(
    'total_payable', coalesce(sum(balance),0),
    'bucket_current', coalesce(sum(balance) filter (where days_overdue = 0),0),
    'bucket_1_30',    coalesce(sum(balance) filter (where days_overdue between 1 and 30),0),
    'bucket_31_60',   coalesce(sum(balance) filter (where days_overdue between 31 and 60),0),
    'bucket_61_90',   coalesce(sum(balance) filter (where days_overdue between 61 and 90),0),
    'bucket_90_plus', coalesce(sum(balance) filter (where days_overdue > 90),0),
    'by_supplier', coalesce((select jsonb_agg(jsonb_build_object(
        'supplier_id',supplier_id,'supplier_name',supplier_name,'balance',bal,'days_overdue',dmax) order by bal desc)
      from (select supplier_id, supplier_name, sum(balance) bal, max(days_overdue) dmax
            from open_inv group by supplier_id, supplier_name) x), '[]'::jsonb)
  ) into v_result from open_inv;
  return v_result;
end; $function$;