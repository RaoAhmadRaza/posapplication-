-- BUG: current_fiscal_period() matched only status='OPEN', so after a period was CLOSED it found
-- nothing and blindly inserted a NEW open period covering the same date — silently defeating
-- close_fiscal_period (every post auto-reopened). Proven: close + post_journal left 1 CLOSED + 1 OPEN.
--
-- FIX: resolve the period covering the date REGARDLESS of status, and return it. If it's CLOSED/LOCKED,
-- the existing trg_journal_check_period trigger rejects the insert (ERR_ACCOUNTING_PERIOD_CLOSED) —
-- the trigger stays the single enforcer. Only auto-create an OPEN period when NO period covers the date
-- at all (genuine gap, e.g. first post of a new month). No auto-reopen, ever.
create or replace function public.current_fiscal_period(p_tenant uuid, p_date date default current_date)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare v_id uuid;
begin
  -- period covering the date, any status; prefer OPEN if somehow multiple overlap
  select id into v_id
    from public.fiscal_periods
   where tenant_id = p_tenant and p_date between start_date and end_date
   order by (status = 'OPEN') desc, start_date desc
   limit 1;

  -- only create when there is genuinely NO period for this date (never to route around a CLOSED one)
  if v_id is null then
    insert into public.fiscal_periods (tenant_id, name, start_date, end_date, status)
    values (p_tenant, to_char(p_date,'Mon YYYY'), date_trunc('month',p_date)::date,
            (date_trunc('month',p_date) + interval '1 month - 1 day')::date, 'OPEN')
    returning id into v_id;
  end if;

  return v_id;
end $$;