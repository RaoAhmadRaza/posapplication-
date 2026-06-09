-- Replace the trigger so signups with a business_name create their own tenant as ADMIN.
-- Signups without a business_name fall back to Demo Store as CASHIER.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  v_business_name text := nullif(trim(new.raw_user_meta_data->>'business_name'), '');
  v_full_name     text := coalesce(new.raw_user_meta_data->>'full_name', '');
  v_tenant_id     uuid;
  v_role_id       uuid;
begin
  if v_business_name is not null then
    insert into public.tenants (name) values (v_business_name)
      returning id into v_tenant_id;
    insert into public.roles (tenant_id, name) values
      (v_tenant_id, 'ADMIN'),
      (v_tenant_id, 'CASHIER');
    select id into v_role_id from public.roles
      where tenant_id = v_tenant_id and name = 'ADMIN' limit 1;
  else
    v_tenant_id := '00000000-0000-0000-0000-000000000001';
    v_role_id   := '00000000-0000-0000-0000-000000000012';
  end if;

  insert into public.users (id, tenant_id, role_id, email, full_name)
  values (new.id, v_tenant_id, v_role_id, new.email, v_full_name)
  on conflict (id) do nothing;
  return new;
end;
$$;
