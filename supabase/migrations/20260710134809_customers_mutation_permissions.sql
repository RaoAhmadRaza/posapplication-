-- Reconciled: customers.tenant_id exists (DATABASE_SCHEMA.md §3.8). 'customers' is a seeded
-- permission module (read/create/update/delete/approve/export).
alter table public.customers enable row level security;

drop policy if exists "customers tenant read" on public.customers;
create policy "customers tenant read" on public.customers
  for select to authenticated
  using (tenant_id = public.auth_tenant_id());

drop policy if exists "customers tenant insert" on public.customers;
create policy "customers tenant insert" on public.customers
  for insert to authenticated
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('customers','create'));

drop policy if exists "customers gated update" on public.customers;
create policy "customers gated update" on public.customers
  for update to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('customers','update'))
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('customers','update'));

drop policy if exists "customers gated delete" on public.customers;
create policy "customers gated delete" on public.customers
  for delete to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('customers','delete'));