-- Customer ledger: invoices (debit / receivable up) + payments (credit) with running balance.
-- Column assumptions (adjust per C0.2/C0.3): invoices(customer_id, grand_total, paid_amount, status,
-- created_at, due_date?); payments(invoice_id, amount, method, created_at). Payments join via invoice.
create or replace function public.customer_ledger(p_customer_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_opening numeric; v_result jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('customers','read') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select opening_balance into v_opening from customers where id=p_customer_id and tenant_id=v_t;
  if not found then raise exception 'ERR_CUSTOMER_NOT_FOUND'; end if;

  with entries as (
    select i.created_at as ts, 'INVOICE' as kind, i.grand_total as debit, 0::numeric as credit,
           i.invoice_number as ref, i.status::text as status
    from invoices i
    where i.customer_id=p_customer_id and i.tenant_id=v_t and i.status <> 'VOID'
    union all
    select p.created_at, 'PAYMENT', 0, p.amount, i.invoice_number, p.method::text
    from payments p join invoices i on i.id=p.invoice_id
    where i.customer_id=p_customer_id and i.tenant_id=v_t
  ), ordered as (
    select *, sum(debit - credit) over (order by ts, kind rows between unbounded preceding and current row) as running
    from entries
  )
  select jsonb_build_object(
    'customer_id', p_customer_id,
    'opening_balance', coalesce(v_opening,0),
    'current_balance', coalesce(v_opening,0) + coalesce((select sum(debit-credit) from entries),0),
    'entries', coalesce((select jsonb_agg(jsonb_build_object(
        'ts',ts,'kind',kind,'debit',debit,'credit',credit,'reference',ref,'status',status,
        'running_balance', coalesce(v_opening,0) + running) order by ts, kind) from ordered), '[]'::jsonb)
  ) into v_result;
  return v_result;
end; $function$;

-- Receivables aging: open invoice balances bucketed by age (mirror payables_aging).
-- Uses due_date if present else created_at date. If invoices has no paid_amount, swap to (grand_total - paid).
create or replace function public.receivables_aging()
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_result jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('customers','read') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  with open_inv as (
    select i.customer_id, c.name as customer_name,
      (i.grand_total - coalesce(i.paid_amount,0)) as balance,
      greatest(0, (current_date - coalesce(i.due_date, i.created_at::date))) as days_overdue
    from invoices i join customers c on c.id=i.customer_id
    where i.tenant_id=v_t and i.status <> 'VOID' and i.customer_id is not null
      and (i.grand_total - coalesce(i.paid_amount,0)) > 0
  )
  select jsonb_build_object(
    'total_receivable', coalesce(sum(balance),0),
    'bucket_current', coalesce(sum(balance) filter (where days_overdue = 0),0),
    'bucket_1_30',    coalesce(sum(balance) filter (where days_overdue between 1 and 30),0),
    'bucket_31_60',   coalesce(sum(balance) filter (where days_overdue between 31 and 60),0),
    'bucket_61_90',   coalesce(sum(balance) filter (where days_overdue between 61 and 90),0),
    'bucket_90_plus', coalesce(sum(balance) filter (where days_overdue > 90),0),
    'by_customer', coalesce((select jsonb_agg(jsonb_build_object(
        'customer_id',customer_id,'customer_name',customer_name,'balance',bal,'days_overdue',dmax) order by bal desc)
      from (select customer_id, customer_name, sum(balance) bal, max(days_overdue) dmax
            from open_inv group by customer_id, customer_name) x), '[]'::jsonb)
  ) into v_result from open_inv;
  return v_result;
end; $function$;