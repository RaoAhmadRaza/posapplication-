-- P3 — wire provisioning into signup. Body is the LIVE P0.1 dump of handle_new_user, VERBATIM,
-- with exactly ONE line added in the new-tenant (business_name) branch after tenant + roles + branch
-- exist: `perform public.provision_tenant(v_tenant_id);`. Nothing else changed.
-- Same signup transaction, NO exception swallow: if provisioning throws, the whole signup rolls back
-- atomically (a failed, retryable signup beats a half-provisioned tenant that cannot post GL).
-- Demo Store fallback branch creates no tenant → no call (already provisioned).

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_business_name   text := nullif(trim(new.raw_user_meta_data->>'business_name'), '');
  v_full_name       text := coalesce(new.raw_user_meta_data->>'full_name', '');
  v_tenant_id       uuid;
  v_role_id         uuid;   -- role assigned to the new user (ADMIN for business owner, CASHIER for fallback)
  v_cashier_role_id uuid;
  v_branch_id       uuid;
begin
  if v_business_name is not null then
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
  else
    v_tenant_id := '00000000-0000-0000-0000-000000000001';   -- Demo Store
    v_role_id   := '00000000-0000-0000-0000-000000000012';   -- Demo Store CASHIER (fallback)
    v_branch_id := '00000000-0000-0000-0000-0000000000b1';   -- Demo Store Main Branch
  end if;

  insert into public.users (id, tenant_id, role_id, email, full_name)
    values (new.id, v_tenant_id, v_role_id, new.email, v_full_name)
    on conflict (id) do nothing;

  insert into public.user_branch_assignments (user_id, branch_id, is_default)
    values (new.id, v_branch_id, true) on conflict (user_id, branch_id) do nothing;

  return new;
end;
$function$;
