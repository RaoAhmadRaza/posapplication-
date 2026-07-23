-- Re-apply the trial_balance as-of fix. Migration 20260723140000 was recorded in
-- the migration history but its CREATE OR REPLACE never took effect on the remote
-- (the live function still LEFT JOINed journal_entries with the date predicate on
-- the left-joined row, so the as-of date was ignored). This forward migration,
-- under a fresh timestamp, guarantees the corrected body is applied. Idempotent.
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
