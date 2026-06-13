-- 20260611173542_fix_softdelete_rls.sql
-- Fix: categories/brands/products UPDATE policies WITH CHECK was rejecting soft-deletes
-- (setting deleted_at). The "new row violates row-level security policy" error (42501)
-- indicates the WITH CHECK clause blocked the post-update row. Relax WITH CHECK to only
-- verify tenant_id, allowing deleted_at to be set. USING still requires inventory:update.

-- Categories
drop policy if exists "categories tenant update" on public.categories;
create policy "categories tenant update" on public.categories
  for update to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('inventory', 'update'))
  with check (tenant_id = public.auth_tenant_id());

-- Brands
drop policy if exists "brands tenant update" on public.brands;
create policy "brands tenant update" on public.brands
  for update to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('inventory', 'update'))
  with check (tenant_id = public.auth_tenant_id());

-- Products
drop policy if exists "products tenant update" on public.products;
create policy "products tenant update" on public.products
  for update to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('inventory', 'update'))
  with check (tenant_id = public.auth_tenant_id());
