-- Reconciled: roles.tenant_id (DATABASE_SCHEMA.md §3.2), tenants.id (§3.1) both exist.
-- RLS pattern = auth_tenant_id(), superseding the schema doc's SET LOCAL app.current_tenant_id
-- prose (DECISIONS.md 2026-06-09; CLAUDE.md §Backend & auth model).

-- roles: read only your own tenant's roles
alter table public.roles enable row level security;
drop policy if exists "roles read" on public.roles;
drop policy if exists "roles tenant read" on public.roles;
create policy "roles tenant read" on public.roles
  for select to authenticated
  using (tenant_id = public.auth_tenant_id());

-- tenants: read only your own tenant row
alter table public.tenants enable row level security;
drop policy if exists "tenants read" on public.tenants;
drop policy if exists "tenants self read" on public.tenants;
create policy "tenants self read" on public.tenants
  for select to authenticated
  using (id = public.auth_tenant_id());