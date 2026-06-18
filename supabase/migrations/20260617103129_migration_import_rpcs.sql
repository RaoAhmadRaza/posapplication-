-- <timestamp>_migration_import_rpcs.sql
-- One SECURITY DEFINER batch RPC per V1 table. Each: forces tenant=auth_tenant_id(), gates inventory:create,
-- preserves the CSV id (on conflict do nothing => idempotent), per-row try/catch, returns {ok,failed,errors}.
-- Stock goes through post_stock_movement (NOT direct) so the ledger + invariant are maintained.

-- helper: slugify (categories/brands need a slug; CSV provides it but regenerate defensively)
create or replace function public.mig_slugify(p text)
returns text language sql immutable as $$
  select trim(both '-' from regexp_replace(lower(coalesce(p,'')), '[^a-z0-9]+', '-', 'g'));
$$;

-- ---- categories ----
create or replace function public.migrate_import_categories(p_rows jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_t uuid := public.auth_tenant_id(); r jsonb; ok int:=0; fail int:=0; errs jsonb:='[]'; i int:=0;
begin
  if v_t is null then raise exception 'no tenant' using errcode='42501'; end if;
  if not public.auth_has_permission('inventory','create') then raise exception 'permission denied' using errcode='42501'; end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    i:=i+1;
    begin
      if coalesce(trim(r->>'name'),'')='' then raise exception 'name required'; end if;
      insert into public.categories (id, tenant_id, name, slug, is_active, sort_order, created_by, updated_by)
      values (coalesce(nullif(r->>'id','')::uuid, gen_random_uuid()), v_t, trim(r->>'name'),
              coalesce(nullif(r->>'slug',''), public.mig_slugify(r->>'name')),
              coalesce((r->>'is_active')::boolean, true), coalesce((r->>'sort_order')::int, 0),
              auth.uid(), auth.uid())
      on conflict (id) do nothing;
      ok:=ok+1;
    exception when others then fail:=fail+1; errs:=errs||jsonb_build_object('row',i,'error',SQLERRM); end;
  end loop;
  return jsonb_build_object('ok',ok,'failed',fail,'errors',errs);
end; $$;

-- ---- brands ----
create or replace function public.migrate_import_brands(p_rows jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_t uuid := public.auth_tenant_id(); r jsonb; ok int:=0; fail int:=0; errs jsonb:='[]'; i int:=0;
begin
  if v_t is null then raise exception 'no tenant' using errcode='42501'; end if;
  if not public.auth_has_permission('inventory','create') then raise exception 'permission denied' using errcode='42501'; end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    i:=i+1;
    begin
      if coalesce(trim(r->>'name'),'')='' then raise exception 'name required'; end if;
      insert into public.brands (id, tenant_id, name, slug, is_active, created_by, updated_by)
      values (coalesce(nullif(r->>'id','')::uuid, gen_random_uuid()), v_t, trim(r->>'name'),
              coalesce(nullif(r->>'slug',''), public.mig_slugify(r->>'name')),
              coalesce((r->>'is_active')::boolean, true), auth.uid(), auth.uid())
      on conflict (id) do nothing;
      ok:=ok+1;
    exception when others then fail:=fail+1; errs:=errs||jsonb_build_object('row',i,'error',SQLERRM); end;
  end loop;
  return jsonb_build_object('ok',ok,'failed',fail,'errors',errs);
end; $$;

-- ---- products ----  (preserve id + sku; brand_id/category_id are CSV UUIDs already loaded above)
create or replace function public.migrate_import_products(p_rows jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_t uuid := public.auth_tenant_id(); r jsonb; ok int:=0; fail int:=0; errs jsonb:='[]'; i int:=0;
        v_cat uuid; v_brand uuid;
begin
  if v_t is null then raise exception 'no tenant' using errcode='42501'; end if;
  if not public.auth_has_permission('inventory','create') then raise exception 'permission denied' using errcode='42501'; end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    i:=i+1;
    begin
      if coalesce(trim(r->>'name'),'')='' then raise exception 'name required'; end if;
      -- only keep category/brand fk if that row actually exists in THIS tenant (else null, don't fail)
      v_cat := null; v_brand := null;
      if coalesce(r->>'category_id','')<>'' then
        select id into v_cat from public.categories where id=(r->>'category_id')::uuid and tenant_id=v_t and deleted_at is null;
      end if;
      if coalesce(r->>'brand_id','')<>'' then
        select id into v_brand from public.brands where id=(r->>'brand_id')::uuid and tenant_id=v_t and deleted_at is null;
      end if;
      insert into public.products
        (id, tenant_id, sku, barcode, name, description, brand_id, category_id,
         selling_price, cost_price, min_selling_price, wholesale_price, unit_of_measure,
         tax_rate, reorder_point, is_active, status, type, created_by, updated_by)
      values
        (coalesce(nullif(r->>'id','')::uuid, gen_random_uuid()), v_t,
         nullif(r->>'sku',''),               -- explicit sku preserved; if null, trigger generates
         nullif(r->>'barcode',''), trim(r->>'name'), nullif(r->>'description',''),
         v_brand, v_cat,
         coalesce((r->>'selling_price')::numeric,0), coalesce((r->>'cost_price')::numeric,0),
         nullif(r->>'min_selling_price','')::numeric, nullif(r->>'wholesale_price','')::numeric,
         coalesce(nullif(r->>'unit_of_measure',''),'PCS'),
         coalesce((r->>'tax_rate')::numeric,0), coalesce((r->>'reorder_point')::int,0),
         coalesce((r->>'is_active')::boolean,true),
         coalesce(nullif(r->>'status','')::product_status_enum,'ACTIVE'),
         coalesce(nullif(r->>'type','')::product_type_enum,'STANDARD'),
         auth.uid(), auth.uid())
      on conflict (id) do nothing;
      ok:=ok+1;
    exception when others then fail:=fail+1; errs:=errs||jsonb_build_object('row',i,'error',SQLERRM); end;
  end loop;
  return jsonb_build_object('ok',ok,'failed',fail,'errors',errs);
end; $$;

-- ---- stock balances ----  routed through post_stock_movement => ledger + invariant maintained.
-- p_branch_id = the importing user's CURRENT branch (tenant rewrite: CSV branch ignored).
-- Each row: OPENING_BALANCE of qty_on_hand at avg_cost. Skips qty<=0 and products not in tenant.
create or replace function public.migrate_import_stock(p_branch_id uuid, p_rows jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_t uuid := public.auth_tenant_id(); r jsonb; ok int:=0; fail int:=0; errs jsonb:='[]'; i int:=0;
        v_pid uuid; v_qty numeric; v_cost numeric; v_exists boolean;
begin
  if v_t is null then raise exception 'no tenant' using errcode='42501'; end if;
  if not public.auth_has_permission('inventory','update') then raise exception 'permission denied' using errcode='42501'; end if;
  if not public.auth_has_branch(p_branch_id) then raise exception 'branch not assigned' using errcode='42501'; end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    i:=i+1;
    begin
      v_pid := (r->>'product_id')::uuid;
      v_qty := coalesce((r->>'qty_on_hand')::numeric, 0);
      v_cost:= coalesce((r->>'avg_cost')::numeric, 0);
      if v_qty <= 0 then ok:=ok+1; continue; end if;   -- nothing to seed
      -- product must exist in this tenant
      if not exists (select 1 from public.products where id=v_pid and tenant_id=v_t and deleted_at is null) then
        raise exception 'product % not in tenant', v_pid;
      end if;
      -- idempotency: skip if a balance already exists for this product at branch default location
      select exists(select 1 from public.stock_balance b
                    where b.tenant_id=v_t and b.branch_id=p_branch_id and b.product_id=v_pid
                      and b.warehouse_id is null) into v_exists;
      if v_exists then ok:=ok+1; continue; end if;
      perform public.post_stock_movement(
        p_branch_id, null, v_pid, null, 'OPENING_BALANCE', v_qty, v_cost, 'MIGRATION', null, 'migration import');
      ok:=ok+1;
    exception when others then fail:=fail+1; errs:=errs||jsonb_build_object('row',i,'error',SQLERRM); end;
  end loop;
  return jsonb_build_object('ok',ok,'failed',fail,'errors',errs);
end; $$;

revoke all on function public.migrate_import_categories(jsonb) from anon, public;
revoke all on function public.migrate_import_brands(jsonb)     from anon, public;
revoke all on function public.migrate_import_products(jsonb)   from anon, public;
revoke all on function public.migrate_import_stock(uuid,jsonb) from anon, public;
grant execute on function public.migrate_import_categories(jsonb) to authenticated;
grant execute on function public.migrate_import_brands(jsonb)     to authenticated;
grant execute on function public.migrate_import_products(jsonb)   to authenticated;
grant execute on function public.migrate_import_stock(uuid,jsonb) to authenticated;