-- Cluster F: there was no way to create a branch — no button, no usecase, no
-- client call, and no create_branch RPC in any of 139 migrations (BRANCH-001/002/003).
-- update_branch_settings could only edit an existing row. This adds the create
-- path, mirroring update_branch_settings' security shape.
--
-- Tenant scope is the isolation floor: the branch is inserted with the CALLER's
-- auth_tenant_id() (never a client-supplied tenant), so a create can't cross
-- tenants. Gated on settings:create (same permission that gates role creation).
--
-- branches.code is NOT NULL and unique per tenant (uq_branches_tenant_code), so a
-- code is derived from the name and de-duplicated with a numeric suffix. is_main
-- is false — the tenant's existing main branch is untouched (single-main invariant
-- preserved). The creator is assigned to the new branch (is_default false) so it
-- appears in their branch list; the insert is ON CONFLICT DO NOTHING against
-- uq_user_branch, so no duplicate user_branch_assignments row can be created (I8).

create or replace function public.create_branch(
  p_name text,
  p_city text default null,
  p_country text default null,
  p_currency text default 'PKR',
  p_timezone text default 'Asia/Karachi'
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_t     uuid := public.auth_tenant_id();
  v_uid   uuid := auth.uid();
  v_base  text;
  v_code  text;
  v_n     int := 0;
  v_branch_id uuid;
begin
  if v_t is null then
    raise exception 'ERR_NO_TENANT' using errcode = '42501';
  end if;
  if not public.auth_has_permission('settings', 'create') then
    raise exception 'ERR_PERMISSION_DENIED' using errcode = '42501';
  end if;
  if coalesce(btrim(p_name), '') = '' then
    raise exception 'ERR_NAME_REQUIRED';
  end if;

  -- Derive a unique per-tenant code from the name (alphanumeric, <=8 chars).
  v_base := upper(regexp_replace(p_name, '[^a-zA-Z0-9]', '', 'g'));
  v_base := left(coalesce(nullif(v_base, ''), 'BR'), 8);
  v_code := v_base;
  while exists (
    select 1 from public.branches where tenant_id = v_t and code = v_code
  ) loop
    v_n := v_n + 1;
    v_code := left(v_base, 6) || lpad(v_n::text, 2, '0');
  end loop;

  insert into public.branches (
    tenant_id, name, code, city, country, currency, timezone, is_main
  ) values (
    v_t, btrim(p_name), v_code,
    nullif(btrim(coalesce(p_city, '')), ''),
    coalesce(nullif(btrim(coalesce(p_country, '')), ''), 'Pakistan'),
    coalesce(nullif(btrim(coalesce(p_currency, '')), ''), 'PKR'),
    coalesce(nullif(btrim(coalesce(p_timezone, '')), ''), 'Asia/Karachi'),
    false
  )
  returning id into v_branch_id;

  -- Assign the creator so the new branch shows in their branch list. I8: the
  -- unique (user_id, branch_id) index makes this idempotent.
  insert into public.user_branch_assignments (user_id, branch_id, is_default)
  values (v_uid, v_branch_id, false)
  on conflict (user_id, branch_id) do nothing;

  return jsonb_build_object('branch_id', v_branch_id, 'code', v_code);
end;
$$;

revoke all on function public.create_branch(text, text, text, text, text)
  from public, anon;
grant execute on function public.create_branch(text, text, text, text, text)
  to authenticated;
