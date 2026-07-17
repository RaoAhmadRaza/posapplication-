-- Phase 4 — handle_new_user() grows a third (invite) branch + gates Demo Store. Basis: RUNBOOK v3 §4.
-- Surgical edits over the 0.2 dump (ADMIN block verbatim). DEVIATION from 4.2 shape (documented):
-- consume_staff_invite writes user_branch_assignments + employees.user_id (both FK->public.users,
-- NOT deferrable — verified), so the invite branch PRE-INSERTS a stub users row (tenant/role nullable),
-- calls consume, then backfills tenant/role — instead of running consume before the users insert.
-- Rollback: psql -f supabase/migrations/_backup_handle_new_user_<ts>.sql (scratchpad copy).

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_invite_token    text := nullif(trim(new.raw_user_meta_data->>'invite_token'), '');
  v_business_name   text := nullif(trim(new.raw_user_meta_data->>'business_name'), '');
  v_full_name       text := coalesce(new.raw_user_meta_data->>'full_name', '');
  v_tenant_id       uuid;
  v_role_id         uuid;   -- role assigned to the new user (ADMIN for business owner, CASHIER for fallback)
  v_cashier_role_id uuid;
  v_branch_id       uuid;
  v_inv             record;
begin
  if v_invite_token is not null then
    -- Join an EXISTING tenant via a staff invite. consume writes child rows that FK to
    -- public.users (non-deferrable), so the users row must exist first: stub -> consume ->
    -- backfill tenant/role. Falls through to the shared tail (its inserts become no-ops).
    insert into public.users (id, email, full_name)
      values (new.id, new.email, nullif(trim(new.raw_user_meta_data->>'full_name'), ''))
      on conflict (id) do nothing;
    select * into v_inv from public.consume_staff_invite(v_invite_token, new.id, new.email);
    v_tenant_id := v_inv.tenant_id;
    v_role_id   := v_inv.role_id;
    v_branch_id := v_inv.default_branch_id;
    update public.users
       set tenant_id = v_tenant_id,
           role_id   = v_role_id,
           full_name = coalesce(nullif(trim(v_full_name), ''), v_inv.full_name)
     where id = new.id;

  elsif v_business_name is not null then
    insert into public.tenants (name) values (v_business_name) returning id into v_tenant_id;

    insert into public.roles (tenant_id, name, is_system_role, hierarchy_level)
      values (v_tenant_id,'ADMIN',true,1) returning id into v_role_id;          -- business owner = ADMIN
    insert into public.roles (tenant_id, name, is_system_role, hierarchy_level)
      values (v_tenant_id,'CASHIER',true,5) returning id into v_cashier_role_id;

    insert into public.branches (tenant_id, name, code, is_main)
      values (v_tenant_id,'Main Branch','BR01',true) returning id into v_branch_id;

    perform public.provision_tenant(v_tenant_id);   -- seeds CoA/series/tax/period/templates/sentinel/warehouse

    -- ADMIN: full matrix
    insert into public.permissions (role_id, module, action, branch_scope, granted)
    select v_role_id, m, a, 'ALL', true
    from unnest(array['sales','inventory','customers','reports','settings','users']) m
    cross join unnest(array['read','create','update','delete','approve','export']) a;

    -- CASHIER: limited matrix
    insert into public.permissions (role_id, module, action, branch_scope, granted) values
      (v_cashier_role_id,'sales','read','OWN_BRANCH',true),
      (v_cashier_role_id,'sales','create','OWN_BRANCH',true),
      (v_cashier_role_id,'inventory','read','OWN_BRANCH',true),
      (v_cashier_role_id,'customers','read','OWN_BRANCH',true),
      (v_cashier_role_id,'customers','create','OWN_BRANCH',true),
      (v_cashier_role_id,'reports','read','OWN_BRANCH',true);

  elsif coalesce(new.raw_user_meta_data->>'demo_mode','false') = 'true' then
    -- Demo Store is now EXPLICITLY gated (was the blank-business-name fallback). Decision 1.
    v_tenant_id := '00000000-0000-0000-0000-000000000001';   -- Demo Store
    v_role_id   := '00000000-0000-0000-0000-000000000012';   -- Demo Store CASHIER (fallback)
    v_branch_id := '00000000-0000-0000-0000-0000000000b1';   -- Demo Store Main Branch

  else
    raise exception 'ERR_SIGNUP_REQUIRES_BUSINESS_OR_INVITE';
  end if;

  insert into public.users (id, tenant_id, role_id, email, full_name)
    values (new.id, v_tenant_id, v_role_id, new.email, v_full_name)
    on conflict (id) do nothing;   -- invite path: row already exists -> no-op

  insert into public.user_branch_assignments (user_id, branch_id, is_default)
    values (new.id, v_branch_id, true) on conflict (user_id, branch_id) do nothing;

  -- 4.5 scrub the raw invite token from auth.users metadata (hash-at-rest never covered this
  -- plaintext copy). Safe: AFTER INSERT, on_auth_user_created is the only trigger on auth.users.
  if v_invite_token is not null then
    update auth.users
       set raw_user_meta_data = raw_user_meta_data - 'invite_token'
     where id = new.id;
  end if;

  return new;
end;
$function$;
