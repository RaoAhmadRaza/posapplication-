-- Fix: customer_ledger() (20260711141631) never emitted the `outstanding` key
-- that CustomerLedgerModel/CustomerLedger, the credit-summary UI, the
-- "Collect payment" CTA gate (customer_detail_page.dart:155 → `outstanding > 0`)
-- and the POS remaining-credit chip (customerOutstandingProvider) all rely on.
-- The model silently defaulted the missing key to 0, so outstanding was ALWAYS
-- 0: the Collect-payment CTA never appeared and the POS chip always read 0.
--
-- `outstanding` is the guard-basis receivable: sum of open invoice balances
-- (invoices.balance = grand_total - paid_amount, maintained by the sales RPCs),
-- excluding VOID, clamped >= 0. This differs from `current_balance`, which is
-- the true net (opening + debits - credits) and can go negative on overpayment.
--
-- Forward migration: `create or replace` the function (additive — the old file
-- is untouched). Body is identical to 20260711141631 except the added
-- `outstanding` key in the returned jsonb.
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
    'outstanding', greatest(coalesce((
        select sum(i.balance) from invoices i
        where i.customer_id=p_customer_id and i.tenant_id=v_t and i.status <> 'VOID'
      ),0), 0),
    'entries', coalesce((select jsonb_agg(jsonb_build_object(
        'ts',ts,'kind',kind,'debit',debit,'credit',credit,'reference',ref,'status',status,
        'running_balance', coalesce(v_opening,0) + running) order by ts, kind) from ordered), '[]'::jsonb)
  ) into v_result;
  return v_result;
end; $function$;
