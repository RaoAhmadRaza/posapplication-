-- Report line items + journal totals for the accounting UI reskin.
-- Additive only: balance_sheet gains a `by_account` breakdown (profit_loss already
-- returns one); a new list_journal_entries RPC returns each entry with its posted
-- total so the journal list can show an amount. No signatures change, no existing
-- keys removed — the four report pages that read totals keep working untouched.

-- Balance sheet: add per-account lines for ASSET / LIABILITY / EQUITY, mirroring
-- the profit_loss `by_account` shape. Existing scalar keys are preserved verbatim.
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
    'balanced', round(v_assets,2) = round(v_liab + v_equity + v_pl,2),
    'by_account', coalesce((select jsonb_agg(jsonb_build_object('code',code,'name',name,'type',type,'amount',amt) order by type,code)
      from (select a.code,a.name,a.type,
             sum(case when a.type='ASSET' then jl.debit-jl.credit else jl.credit-jl.debit end) amt
            from journal_lines jl join accounts a on a.id=jl.account_id
              join journal_entries je on je.id=jl.journal_entry_id
            where je.tenant_id=v_t and a.type in ('ASSET','LIABILITY','EQUITY') and je.created_at::date <= p_as_of
              and (p_branch_id is null or je.branch_id=p_branch_id)
            group by a.code,a.name,a.type having sum(jl.debit+jl.credit)<>0) x),'[]'::jsonb)
  ) into v_result;
  return v_result;
end; $function$;

-- Journal list with per-entry total (= sum of the entry's debits, which equals its
-- credits for a balanced entry). Tenant-scoped only — no permission gate, matching
-- the ungated table read this replaces. SECURITY DEFINER, so tenant is filtered
-- explicitly since RLS is bypassed.
create or replace function public.list_journal_entries(p_limit int default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_result jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  select coalesce(jsonb_agg(row_to_json(e) order by e.created_at desc), '[]'::jsonb) into v_result
  from (
    select je.id, je.tenant_id, je.entry_number, je.reference_id, je.reference_type,
           je.description, je.period_id, je.branch_id, je.is_reversing,
           je.reversed_entry_id, je.posted_by, je.correlation_id, je.created_at,
           coalesce((select sum(jl.debit) from journal_lines jl where jl.journal_entry_id=je.id),0) as total
    from journal_entries je
    where je.tenant_id=v_t
    order by je.created_at desc
    limit p_limit
  ) e;
  return v_result;
end; $function$;

grant execute on function public.list_journal_entries(int) to authenticated;
