-- Phase 6 enabler — list_tenant_users(): the role-management UI (update_user_role, 5.5) needs to
-- pick a user, but public.users RLS is read-own-only. This users:read-gated definer RPC returns the
-- tenant's users + their role, mirroring list_staff_invites/list_tenant_roles.
create or replace function public.list_tenant_users()
returns table (id uuid, full_name text, email text, role_id uuid, role_name text,
               hierarchy_level integer, status text, last_login_at timestamptz)
language sql security definer stable set search_path = public as $$
  select u.id, u.full_name, u.email, u.role_id, r.name, r.hierarchy_level, u.status, u.last_login_at
  from public.users u
  left join public.roles r on r.id = u.role_id
  where u.tenant_id = public.auth_tenant_id()
    and public.auth_has_permission('users','read')
  order by u.full_name nulls last, u.email;
$$;
revoke all on function public.list_tenant_users() from public, anon;
grant execute on function public.list_tenant_users() to authenticated;
