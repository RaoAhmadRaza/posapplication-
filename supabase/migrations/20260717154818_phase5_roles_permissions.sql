-- Phase 5 — Roles & Permissions RPCs. Basis: RUNBOOK v3 §5.
-- All SECURITY DEFINER, session-gated (auth_tenant_id/auth_has_permission). 5.6 example seed
-- is NOT run here (create_tenant_role needs an admin session; run via UI/owner per tenant).

-- ===== 5.1  list_permission_catalog (the grantable vocabulary = what ADMIN holds) =====
create or replace function public.list_permission_catalog()
returns table (module text, action text)
language sql security definer stable set search_path = public as $$
  select distinct p.module, p.action from public.permissions p
  join public.roles r on r.id = p.role_id
  where r.tenant_id = public.auth_tenant_id()
    and public.is_admin_role_name(r.name) and p.granted = true
  order by 1, 2;
$$;
revoke all on function public.list_permission_catalog() from public, anon;
grant execute on function public.list_permission_catalog() to authenticated;

-- ===== 5.2  create_tenant_role (subset gate per-permission; role starts EMPTY —
-- the 7 seed_*_perms triggers only fire for NEW.name='ADMIN') =====
create or replace function public.create_tenant_role(
  p_name text, p_description text, p_hierarchy_level integer, p_permissions jsonb
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_tenant_id uuid := public.auth_tenant_id();
  v_role_id uuid; v_my_level integer; v_perm jsonb;
  v_i_am_admin boolean := public.is_admin_role_name(public.auth_role_name());
begin
  if v_tenant_id is null then raise exception 'ERR_NO_TENANT'; end if;
  if not public.auth_has_permission('settings','create') then raise exception 'ERR_FORBIDDEN'; end if;
  if public.is_admin_role_name(p_name) then raise exception 'ERR_RESERVED_ROLE_NAME'; end if;
  if p_hierarchy_level is null or p_hierarchy_level < 2 or p_hierarchy_level > 99 then
    raise exception 'ERR_INVALID_HIERARCHY';
  end if;

  select r.hierarchy_level into v_my_level from public.roles r where r.id = public.auth_role_id();
  if not v_i_am_admin and p_hierarchy_level <= coalesce(v_my_level, 99) then
    raise exception 'ERR_HIERARCHY_VIOLATION';
  end if;

  for v_perm in select * from jsonb_array_elements(p_permissions) loop
    if not public.auth_has_permission(v_perm->>'module', v_perm->>'action') then
      raise exception 'ERR_CANNOT_GRANT_UNHELD_PERMISSION: %.%', v_perm->>'module', v_perm->>'action';
    end if;
  end loop;

  insert into public.roles (tenant_id, name, description, is_system_role, hierarchy_level)
  values (v_tenant_id, trim(p_name), p_description, false, p_hierarchy_level)
  returning id into v_role_id;

  for v_perm in select * from jsonb_array_elements(p_permissions) loop
    insert into public.permissions (role_id, module, action, branch_scope, granted)
    values (v_role_id, v_perm->>'module', v_perm->>'action',
            coalesce((v_perm->>'branch_scope')::public.branch_scope_enum,'OWN_BRANCH'), true);
  end loop;
  return v_role_id;
end $$;
revoke all on function public.create_tenant_role(text, text, integer, jsonb) from public, anon;
grant execute on function public.create_tenant_role(text, text, integer, jsonb) to authenticated;

-- ===== 5.3  update_role_permissions / list_tenant_roles =====
create or replace function public.update_role_permissions(p_role_id uuid, p_permissions jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare v_perm jsonb; v_role public.roles%rowtype; v_my_level integer;
        v_i_am_admin boolean := public.is_admin_role_name(public.auth_role_name());
begin
  if not public.auth_has_permission('settings','update') then raise exception 'ERR_FORBIDDEN'; end if;
  select * into v_role from public.roles where id = p_role_id and tenant_id = public.auth_tenant_id();
  if not found then raise exception 'ERR_ROLE_NOT_IN_TENANT'; end if;
  if public.is_admin_role_name(v_role.name) or v_role.is_system_role then
    raise exception 'ERR_SYSTEM_ROLE_IMMUTABLE'; end if;
  if p_role_id = public.auth_role_id() then raise exception 'ERR_CANNOT_EDIT_OWN_ROLE'; end if;

  select r.hierarchy_level into v_my_level from public.roles r where r.id = public.auth_role_id();
  if not v_i_am_admin and coalesce(v_role.hierarchy_level,99) <= coalesce(v_my_level,99) then
    raise exception 'ERR_HIERARCHY_VIOLATION';
  end if;
  for v_perm in select * from jsonb_array_elements(p_permissions) loop
    if not public.auth_has_permission(v_perm->>'module', v_perm->>'action') then
      raise exception 'ERR_CANNOT_GRANT_UNHELD_PERMISSION'; end if;
  end loop;

  delete from public.permissions where role_id = p_role_id;
  for v_perm in select * from jsonb_array_elements(p_permissions) loop
    insert into public.permissions (role_id, module, action, branch_scope, granted)
    values (p_role_id, v_perm->>'module', v_perm->>'action',
            coalesce((v_perm->>'branch_scope')::public.branch_scope_enum,'OWN_BRANCH'), true);
  end loop;
end $$;

create or replace function public.list_tenant_roles()
returns table (id uuid, name text, description text, hierarchy_level integer,
               is_system_role boolean, permission_count bigint, user_count bigint)
language sql security definer stable set search_path = public as $$
  select r.id, r.name, r.description, r.hierarchy_level, r.is_system_role,
         (select count(*) from public.permissions p where p.role_id = r.id and p.granted),
         (select count(*) from public.users u where u.role_id = r.id)
  from public.roles r where r.tenant_id = public.auth_tenant_id()
  order by r.hierarchy_level, r.name;
$$;
revoke all on function public.update_role_permissions(uuid, jsonb) from public, anon;
grant execute on function public.update_role_permissions(uuid, jsonb) to authenticated;
revoke all on function public.list_tenant_roles() from public, anon;
grant execute on function public.list_tenant_roles() to authenticated;

-- ===== 5.5  update_user_role — the SECOND escalation door. Carries the identical four-guard
-- set as create_staff_invite (R2 #2) + a last-admin lockout. Edit one, edit both. =====
create or replace function public.update_user_role(p_user_id uuid, p_role_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_tenant_id uuid := public.auth_tenant_id();
  v_tgt_name text; v_tgt_level integer;
  v_cur_role_name text; v_my_level integer; v_admin_count integer;
  v_i_am_admin boolean := public.is_admin_role_name(public.auth_role_name());
begin
  if v_tenant_id is null then raise exception 'ERR_NO_TENANT'; end if;
  if not public.auth_has_permission('users','update') then raise exception 'ERR_FORBIDDEN'; end if;
  if p_user_id = auth.uid() then raise exception 'ERR_CANNOT_CHANGE_OWN_ROLE'; end if;

  if not exists (select 1 from public.users u where u.id = p_user_id and u.tenant_id = v_tenant_id) then
    raise exception 'ERR_USER_NOT_IN_TENANT';
  end if;

  select r.name, r.hierarchy_level into v_tgt_name, v_tgt_level
  from public.roles r where r.id = p_role_id and r.tenant_id = v_tenant_id;
  if not found then raise exception 'ERR_ROLE_NOT_IN_TENANT'; end if;

  -- GUARD 1 (name, drift-proof) — identical to create_staff_invite
  if public.is_admin_role_name(v_tgt_name) and not v_i_am_admin then
    raise exception 'ERR_ONLY_ADMIN_CAN_CREATE_ADMIN';
  end if;

  -- GUARD 2 (subset, drift-proof) — identical to create_staff_invite
  if not v_i_am_admin and not public.auth_can_grant_role(p_role_id) then
    raise exception 'ERR_CANNOT_GRANT_UNHELD_PERMISSION';
  end if;

  -- GUARD 3 (level) — identical; actor can't promote a target above the actor's own tier
  select r.hierarchy_level into v_my_level from public.roles r where r.id = public.auth_role_id();
  if not v_i_am_admin and coalesce(v_tgt_level,99) <= coalesce(v_my_level,99) then
    raise exception 'ERR_HIERARCHY_VIOLATION';
  end if;

  -- GUARD 5 (lockout): never demote the last ADMIN — that bricks the tenant
  select r.name into v_cur_role_name
  from public.users u join public.roles r on r.id = u.role_id where u.id = p_user_id;
  if public.is_admin_role_name(v_cur_role_name) and not public.is_admin_role_name(v_tgt_name) then
    select count(*) into v_admin_count
    from public.users u join public.roles r on r.id = u.role_id
    where u.tenant_id = v_tenant_id and public.is_admin_role_name(r.name);
    if v_admin_count <= 1 then raise exception 'ERR_LAST_ADMIN_CANNOT_BE_DEMOTED'; end if;
  end if;

  update public.users set role_id = p_role_id, updated_at = now() where id = p_user_id;
end $$;
revoke all on function public.update_user_role(uuid, uuid) from public, anon;
grant execute on function public.update_user_role(uuid, uuid) to authenticated;
