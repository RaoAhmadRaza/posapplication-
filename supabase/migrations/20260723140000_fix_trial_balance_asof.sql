-- Fix: trial_balance ignored the as-of date (and branch) filter.
-- The original query LEFT JOINed journal_lines -> journal_entries and placed the
-- `created_at <= p_as_of` / branch predicate on the left-joined je. Because the
-- totals sum journal_lines (jl) directly, those rows survive the left join even
-- when je fails the date condition, so every as-of date returned the same
-- numbers. Fix: aggregate the date/branch-filtered lines with an INNER join
-- first, then LEFT JOIN the result onto accounts (so zero-activity accounts are
-- simply dropped by the existing dr<>0 or cr<>0 filter). Return shape unchanged.
create or replace function public.trial_balance(p_as_of date default current_date, p_branch_id uuid default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_result jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','read') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  with activity as (
    select jl.account_id,
      coalesce(sum(jl.debit),0) as dr, coalesce(sum(jl.credit),0) as cr
    from journal_lines jl
    join journal_entries je on je.id = jl.journal_entry_id
    where je.tenant_id = v_t
      and je.created_at::date <= p_as_of
      and (p_branch_id is null or je.branch_id = p_branch_id)
    group by jl.account_id
  ), sums as (
    select a.id, a.code, a.name, a.type,
      coalesce(act.dr,0) as dr, coalesce(act.cr,0) as cr
    from accounts a
    left join activity act on act.account_id = a.id
    where a.tenant_id = v_t and a.deleted_at is null
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
