-- Trial balance as of a date: per account, sum debits/credits, net by normal side.
create or replace function public.trial_balance(p_as_of date default current_date, p_branch_id uuid default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_result jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','read') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  with sums as (
    select a.id, a.code, a.name, a.type,
      coalesce(sum(jl.debit),0) as dr, coalesce(sum(jl.credit),0) as cr
    from accounts a
    left join journal_lines jl on jl.account_id=a.id
    left join journal_entries je on je.id=jl.journal_entry_id
      and je.tenant_id=v_t and je.created_at::date <= p_as_of
      and (p_branch_id is null or je.branch_id = p_branch_id)
    where a.tenant_id=v_t and a.deleted_at is null
    group by a.id, a.code, a.name, a.type
  )
  select jsonb_build_object(
    'as_of', p_as_of,
    'total_debit', coalesce(sum(greatest(dr-cr,0)),0),
    'total_credit', coalesce(sum(greatest(cr-dr,0)),0),
    'balanced', coalesce(sum(dr),0) = coalesce(sum(cr),0),
    'rows', coalesce(jsonb_agg(jsonb_build_object('code',code,'name',name,'type',type,
              'debit',greatest(dr-cr,0),'credit',greatest(cr-dr,0)) order by code)
              filter (where dr<>0 or cr<>0), '[]'::jsonb)
  ) into v_result from sums;
  return v_result;
end; $function$;

-- P&L for a date range: REVENUE (credit-normal) − EXPENSE (debit-normal).
create or replace function public.profit_loss(p_from date, p_to date, p_branch_id uuid default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_rev numeric; v_exp numeric; v_result jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','read') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select
    coalesce(sum(case when a.type='REVENUE' then jl.credit - jl.debit else 0 end),0),
    coalesce(sum(case when a.type='EXPENSE' then jl.debit - jl.credit else 0 end),0)
    into v_rev, v_exp
  from journal_lines jl join accounts a on a.id=jl.account_id
    join journal_entries je on je.id=jl.journal_entry_id
  where je.tenant_id=v_t and je.created_at::date between p_from and p_to
    and (p_branch_id is null or je.branch_id=p_branch_id);
  select jsonb_build_object(
    'from',p_from,'to',p_to,'revenue',v_rev,'expenses',v_exp,'net_profit',v_rev - v_exp,
    'by_account', coalesce((select jsonb_agg(jsonb_build_object('code',code,'name',name,'type',type,'amount',amt) order by type,code)
      from (select a.code,a.name,a.type,
             sum(case when a.type='REVENUE' then jl.credit-jl.debit else jl.debit-jl.credit end) amt
            from journal_lines jl join accounts a on a.id=jl.account_id
              join journal_entries je on je.id=jl.journal_entry_id
            where je.tenant_id=v_t and a.type in ('REVENUE','EXPENSE') and je.created_at::date between p_from and p_to
              and (p_branch_id is null or je.branch_id=p_branch_id)
            group by a.code,a.name,a.type having sum(jl.debit+jl.credit)<>0) x),'[]'::jsonb)
  ) into v_result;
  return v_result;
end; $function$;

-- Balance sheet as of a date: ASSET = LIABILITY + EQUITY (+ retained P&L to date).
create or replace function public.balance_sheet(p_as_of date default current_date, p_branch_id uuid default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_assets numeric; v_liab numeric; v_equity numeric; v_pl numeric; v_result jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','read') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select
    coalesce(sum(case when a.type='ASSET' then jl.debit-jl.credit else 0 end),0),
    coalesce(sum(case when a.type='LIABILITY' then jl.credit-jl.debit else 0 end),0),
    coalesce(sum(case when a.type='EQUITY' then jl.credit-jl.debit else 0 end),0),
    coalesce(sum(case when a.type='REVENUE' then jl.credit-jl.debit when a.type='EXPENSE' then -(jl.debit-jl.credit) else 0 end),0)
    into v_assets, v_liab, v_equity, v_pl
  from journal_lines jl join accounts a on a.id=jl.account_id
    join journal_entries je on je.id=jl.journal_entry_id
  where je.tenant_id=v_t and je.created_at::date <= p_as_of and (p_branch_id is null or je.branch_id=p_branch_id);
  select jsonb_build_object(
    'as_of',p_as_of,'assets',v_assets,'liabilities',v_liab,
    'equity',v_equity,'retained_earnings',v_pl,'equity_total',v_equity + v_pl,
    'balanced', round(v_assets,2) = round(v_liab + v_equity + v_pl,2)
  ) into v_result;
  return v_result;
end; $function$;

-- Account ledger: full transaction history for one account with running balance.
create or replace function public.account_ledger(p_account_id uuid, p_from date default null, p_to date default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_open numeric; v_result jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','read') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select opening_balance into v_open from accounts where id=p_account_id and tenant_id=v_t;
  if not found then raise exception 'ERR_ACCOUNT_NOT_FOUND'; end if;
  with lines as (
    select je.created_at ts, je.entry_number, je.description, jl.debit, jl.credit
    from journal_lines jl join journal_entries je on je.id=jl.journal_entry_id
    where jl.account_id=p_account_id and je.tenant_id=v_t
      and (p_from is null or je.created_at::date >= p_from)
      and (p_to is null or je.created_at::date <= p_to)
  ), ordered as (
    select *, sum(debit-credit) over (order by ts rows between unbounded preceding and current row) run from lines
  )
  select jsonb_build_object('account_id',p_account_id,'opening_balance',coalesce(v_open,0),
    'entries', coalesce((select jsonb_agg(jsonb_build_object('ts',ts,'entry_number',entry_number,
      'description',description,'debit',debit,'credit',credit,'running_balance',coalesce(v_open,0)+run) order by ts) from ordered),'[]'::jsonb)
  ) into v_result;
  return v_result;
end; $function$;

-- Cash book / bank book: ledger for account 1000 (cash) or a bank's chart account.
create or replace function public.cash_bank_book(p_account_code varchar, p_from date, p_to date)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_acct uuid;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  v_acct := public.acct_id(v_t, p_account_code);
  if v_acct is null then raise exception 'ERR_ACCOUNT_NOT_FOUND'; end if;
  return public.account_ledger(v_acct, p_from, p_to);
end; $function$;