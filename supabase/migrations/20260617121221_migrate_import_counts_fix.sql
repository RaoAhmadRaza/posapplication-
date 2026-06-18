-- 20260617121221_migrate_import_counts_fix.sql
-- Distinguishes three outcomes: inserted, skipped (idempotent), failed (real error).
-- Rewrites categories/brands/products RPCs with CTE-based count tracking.
-- Stock RPC also updated with inserted/skipped/failed tracking.

-- ===== categories — set-based with three-count return =====
create or replace function public.migrate_import_categories(p_rows jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_t uuid := public.auth_tenant_id();
  v_total int;
  v_ins int;
  v_valid int;
begin
  set local statement_timeout = 0;
  if v_t is null then raise exception 'no tenant' using errcode='42501'; end if;
  if not public.auth_has_permission('inventory','create') then
    raise exception 'permission denied' using errcode='42501';
  end if;

  v_total := jsonb_array_length(p_rows);
  if v_total = 0 then
    return jsonb_build_object('inserted',0,'skipped',0,'failed',0,'ok',0,'errors','[]'::jsonb);
  end if;

  with input as (
    select e,
           coalesce(nullif(e->>'id','')::uuid, gen_random_uuid()) as rid,
           trim(e->>'name') as nm
    from jsonb_array_elements(p_rows) e
  ),
  valid as (
    select * from input where coalesce(nm, '') <> ''
  ),
  ins as (
    insert into public.categories (id, tenant_id, name, slug, is_active, sort_order, created_by, updated_by)
    select rid, v_t, nm,
           coalesce(nullif(e->>'slug',''), public.mig_slugify(nm)),
           coalesce((e->>'is_active')::boolean, true),
           coalesce((e->>'sort_order')::int, 0),
           auth.uid(), auth.uid()
    from valid
    on conflict (id) do nothing
    returning 1
  )
  select (select count(*) from ins), (select count(*) from valid)
    into v_ins, v_valid;

  return jsonb_build_object(
    'inserted', v_ins,
    'skipped',  v_valid - v_ins,
    'failed',   v_total - v_valid,
    'ok',       v_valid,
    'errors',   '[]'::jsonb
  );
end; $$;

-- ===== brands — set-based with three-count return =====
create or replace function public.migrate_import_brands(p_rows jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_t uuid := public.auth_tenant_id();
  v_total int;
  v_ins int;
  v_valid int;
begin
  set local statement_timeout = 0;
  if v_t is null then raise exception 'no tenant' using errcode='42501'; end if;
  if not public.auth_has_permission('inventory','create') then
    raise exception 'permission denied' using errcode='42501';
  end if;

  v_total := jsonb_array_length(p_rows);
  if v_total = 0 then
    return jsonb_build_object('inserted',0,'skipped',0,'failed',0,'ok',0,'errors','[]'::jsonb);
  end if;

  with input as (
    select e,
           coalesce(nullif(e->>'id','')::uuid, gen_random_uuid()) as rid,
           trim(e->>'name') as nm
    from jsonb_array_elements(p_rows) e
  ),
  valid as (
    select * from input where coalesce(nm, '') <> ''
  ),
  ins as (
    insert into public.brands (id, tenant_id, name, slug, is_active, created_by, updated_by)
    select rid, v_t, nm,
           coalesce(nullif(e->>'slug',''), public.mig_slugify(nm)),
           coalesce((e->>'is_active')::boolean, true),
           auth.uid(), auth.uid()
    from valid
    on conflict (id) do nothing
    returning 1
  )
  select (select count(*) from ins), (select count(*) from valid)
    into v_ins, v_valid;

  return jsonb_build_object(
    'inserted', v_ins,
    'skipped',  v_valid - v_ins,
    'failed',   v_total - v_valid,
    'ok',       v_valid,
    'errors',   '[]'::jsonb
  );
end; $$;

-- ===== products — set-based with three-count return + barcode dedup =====
create or replace function public.migrate_import_products(p_rows jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_t uuid := public.auth_tenant_id();
  v_total int;
  v_ins int;
  v_valid int;
begin
  set local statement_timeout = 0;
  if v_t is null then raise exception 'no tenant' using errcode='42501'; end if;
  if not public.auth_has_permission('inventory','create') then
    raise exception 'permission denied' using errcode='42501';
  end if;

  v_total := jsonb_array_length(p_rows);
  if v_total = 0 then
    return jsonb_build_object('inserted',0,'skipped',0,'failed',0,'ok',0,'errors','[]'::jsonb);
  end if;

  with input as (
    select
      coalesce(nullif(e->>'id','')::uuid, gen_random_uuid()) as rid,
      e->>'sku' as _sku,
      e->>'barcode' as _barcode,
      trim(e->>'name') as nm,
      e->>'description' as _desc,
      nullif(e->>'brand_id','')::uuid as _brand_id,
      nullif(e->>'category_id','')::uuid as _cat_id,
      e->>'selling_price' as _sp,
      e->>'cost_price' as _cp,
      e->>'min_selling_price' as _msp,
      e->>'wholesale_price' as _wp,
      e->>'unit_of_measure' as _uom,
      e->>'tax_rate' as _tax,
      e->>'reorder_point' as _rp,
      e->>'is_active' as _ia,
      e->>'status' as _st,
      e->>'type' as _ty
    from jsonb_array_elements(p_rows) e
    where coalesce(trim(e->>'name'), '') <> ''
  ),
  deduped as (
    select distinct on (coalesce(nullif(_barcode,''), rid::text)) *
    from input
    order by coalesce(nullif(_barcode,''), rid::text)
  ),
  valid as (
    select d.*
    from deduped d
    where not exists (
      select 1 from public.products p2
      where p2.tenant_id = v_t
        and p2.barcode = nullif(d._barcode, '')
        and p2.barcode is not null
        and p2.deleted_at is null
        and p2.id is distinct from d.rid
    )
  ),
  ins as (
    insert into public.products (
      id, tenant_id, sku, barcode, name, description, brand_id, category_id,
      selling_price, cost_price, min_selling_price, wholesale_price, unit_of_measure,
      tax_rate, reorder_point, is_active, status, type, created_by, updated_by
    )
    select
      rid, v_t,
      nullif(_sku, ''), nullif(_barcode, ''), nm, nullif(_desc, ''),
      b.id, c.id,
      coalesce(_sp::numeric, 0), coalesce(_cp::numeric, 0),
      nullif(_msp, '')::numeric, nullif(_wp, '')::numeric,
      coalesce(nullif(_uom, ''), 'PCS'),
      coalesce(_tax::numeric, 0), coalesce(_rp::int, 0),
      coalesce(_ia::boolean, true),
      coalesce(nullif(_st, '')::product_status_enum, 'ACTIVE'),
      coalesce(nullif(_ty, '')::product_type_enum, 'STANDARD'),
      auth.uid(), auth.uid()
    from valid d
    left join public.brands b
      on b.id = d._brand_id and b.tenant_id = v_t and b.deleted_at is null
    left join public.categories c
      on c.id = d._cat_id and c.tenant_id = v_t and c.deleted_at is null
    on conflict (id) do nothing
    returning 1
  )
  select (select count(*) from ins), (select count(*) from deduped)
    into v_ins, v_valid;

  return jsonb_build_object(
    'inserted', v_ins,
    'skipped',  v_valid - v_ins,
    'failed',   v_total - (select count(*) from input),
    'ok',       v_valid,
    'errors',   '[]'::jsonb
  );
end; $$;

-- ===== stock — row-by-row with three-count return =====
create or replace function public.migrate_import_stock(p_branch_id uuid, p_rows jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_t uuid := public.auth_tenant_id();
  r jsonb;
  v_ins int := 0;
  v_skp int := 0;
  v_fail int := 0;
  errs jsonb := '[]'::jsonb;
  i int := 0;
  v_pid uuid;
  v_qty numeric;
  v_cost numeric;
  v_exists boolean;
begin
  set local statement_timeout = 0;

  if v_t is null then raise exception 'no tenant' using errcode='42501'; end if;
  if not public.auth_has_permission('inventory','update') then
    raise exception 'permission denied' using errcode='42501';
  end if;
  if not public.auth_has_branch(p_branch_id) then
    raise exception 'branch not assigned' using errcode='42501';
  end if;

  for r in select * from jsonb_array_elements(p_rows) loop
    i := i + 1;
    begin
      v_pid := (r->>'product_id')::uuid;
      v_qty := coalesce((r->>'qty_on_hand')::numeric, 0);
      v_cost := coalesce((r->>'avg_cost')::numeric, 0);
      if v_qty <= 0 then v_skp := v_skp + 1; continue; end if;
      if not exists (select 1 from public.products
                     where id = v_pid and tenant_id = v_t and deleted_at is null) then
        raise exception 'product % not in tenant', v_pid;
      end if;
      select exists(select 1 from public.stock_balance b
                    where b.tenant_id = v_t and b.branch_id = p_branch_id
                      and b.product_id = v_pid and b.warehouse_id is null)
        into v_exists;
      if v_exists then v_skp := v_skp + 1; continue; end if;
      perform public.post_stock_movement(
        p_branch_id, null, v_pid, null, 'OPENING_BALANCE',
        v_qty, v_cost, 'MIGRATION', null, 'migration import');
      v_ins := v_ins + 1;
    exception when others then
      v_fail := v_fail + 1;
      errs := errs || jsonb_build_object('row', i, 'error', SQLERRM);
    end;
  end loop;

  return jsonb_build_object(
    'inserted', v_ins,
    'skipped',  v_skp,
    'failed',   v_fail,
    'ok',       v_ins + v_skp,
    'errors',   errs
  );
end; $$;

revoke all on function public.migrate_import_categories(jsonb) from anon, public;
revoke all on function public.migrate_import_brands(jsonb) from anon, public;
revoke all on function public.migrate_import_products(jsonb) from anon, public;
revoke all on function public.migrate_import_stock(uuid, jsonb) from anon, public;
grant execute on function public.migrate_import_categories(jsonb) to authenticated;
grant execute on function public.migrate_import_brands(jsonb) to authenticated;
grant execute on function public.migrate_import_products(jsonb) to authenticated;
grant execute on function public.migrate_import_stock(uuid, jsonb) to authenticated;
