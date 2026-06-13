-- 20260612000000_inventory_softdelete_rpcs.sql
-- Permanent fix for inventory soft-delete (categories/brands/products).
--
-- Root symptom: an UPDATE that sets only deleted_at was rejected by the brands/categories/products
-- UPDATE policy with 42501 "new row violates row-level security policy", even though, in the same
-- transaction under the real authenticated role, tenant_id = auth_tenant_id() evaluates to TRUE and
-- the row's tenant is correct. The WITH CHECK predicate is provably satisfiable yet the write fails.
--
-- Rather than depend on resolving that RLS-evaluation anomaly, soft-delete is moved into
-- SECURITY DEFINER functions. They run as the table owner (FORCE ROW LEVEL SECURITY is off, verified),
-- so the write is not subject to the UPDATE WITH CHECK. Tenant isolation and permission are enforced
-- EXPLICITLY inside each function, so security is preserved (arguably tighter: delete now requires the
-- inventory:delete permission, matching the UI gate, instead of inventory:update).
--
-- Idempotent + additive. Apply via: supabase migration new ... -> paste -> supabase db push.

-- ===========================================================================
-- 1. Clean rebuild: exactly ONE UPDATE policy per catalog table.
--    Collapses the duplicate "<table> tenant update" added by 20260611173542.
--    WITH CHECK verifies tenant ONLY (never deleted_at), so ordinary edits work.
-- ===========================================================================
drop policy if exists "brands update"        on public.brands;
drop policy if exists "brands tenant update" on public.brands;
create policy "brands update" on public.brands
  for update to authenticated
  using      (tenant_id = public.auth_tenant_id() and public.auth_has_permission('inventory','update'))
  with check (tenant_id = public.auth_tenant_id());

drop policy if exists "categories update"        on public.categories;
drop policy if exists "categories tenant update" on public.categories;
create policy "categories update" on public.categories
  for update to authenticated
  using      (tenant_id = public.auth_tenant_id() and public.auth_has_permission('inventory','update'))
  with check (tenant_id = public.auth_tenant_id());

drop policy if exists "products update"        on public.products;
drop policy if exists "products tenant update" on public.products;
create policy "products update" on public.products
  for update to authenticated
  using      (tenant_id = public.auth_tenant_id() and public.auth_has_permission('inventory','update'))
  with check (tenant_id = public.auth_tenant_id());

-- ===========================================================================
-- 2. SECURITY DEFINER soft-delete RPCs (the actual fix).
--    Owner-run => bypasses the UPDATE WITH CHECK. Safety enforced inline:
--      - inventory:delete permission required
--      - row must belong to caller's tenant
--      - row must not already be soft-deleted
--    The BEFORE UPDATE trigger (fn_touch_row) still fires and bumps version/updated_at.
-- ===========================================================================
create or replace function public.soft_delete_brand(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.auth_has_permission('inventory','delete') then
    raise exception 'permission denied' using errcode = '42501';
  end if;
  update public.brands
     set deleted_at = now(),
         updated_by = auth.uid()
   where id = p_id
     and tenant_id = public.auth_tenant_id()
     and deleted_at is null;
  if not found then
    raise exception 'brand % not found in tenant', p_id using errcode = 'P0002';
  end if;
end; $$;

create or replace function public.soft_delete_category(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.auth_has_permission('inventory','delete') then
    raise exception 'permission denied' using errcode = '42501';
  end if;
  update public.categories
     set deleted_at = now(),
         updated_by = auth.uid()
   where id = p_id
     and tenant_id = public.auth_tenant_id()
     and deleted_at is null;
  if not found then
    raise exception 'category % not found in tenant', p_id using errcode = 'P0002';
  end if;
end; $$;

create or replace function public.soft_delete_product(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.auth_has_permission('inventory','delete') then
    raise exception 'permission denied' using errcode = '42501';
  end if;
  update public.products
     set deleted_at = now(),
         updated_by = auth.uid()
   where id = p_id
     and tenant_id = public.auth_tenant_id()
     and deleted_at is null;
  if not found then
    raise exception 'product % not found in tenant', p_id using errcode = 'P0002';
  end if;
end; $$;

-- Lock down: only logged-in users may execute; never anon/public.
revoke all on function public.soft_delete_brand(uuid)    from anon, public;
revoke all on function public.soft_delete_category(uuid) from anon, public;
revoke all on function public.soft_delete_product(uuid)  from anon, public;
grant execute on function public.soft_delete_brand(uuid)    to authenticated;
grant execute on function public.soft_delete_category(uuid) to authenticated;
grant execute on function public.soft_delete_product(uuid)  to authenticated;