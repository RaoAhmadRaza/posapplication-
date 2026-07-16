-- ===== FIX: soft-delete tombstones never reached the client. =====
-- sync_pull_reference was SECURITY INVOKER. products/product_variants read RLS is
-- (tenant_id = auth_tenant_id() AND deleted_at IS NULL) — so RLS stripped every soft-deleted row
-- BEFORE the function saw it. A deleted product was invisible to the delta (identical to a hard delete),
-- so the offline client never got its ONLY eviction signal and kept selling deleted items forever.
-- (customers/payment_methods/tax_rules read policies have NO deleted_at clause, so they were already fine.)
--
-- SECURITY DEFINER bypasses RLS, so the tombstone (deleted_at set, updated_at bumped) now rides the delta.
-- Tenant isolation is UNCHANGED: every subquery already filters `where tenant_id = v_tenant` explicitly, and
-- v_tenant = auth_tenant_id() (the caller's own tenant, role-independent — this function calls NO
-- auth_has_permission, so ADMIN and CASHIER resolve the identical tenant and see the identical rows).
-- The explicit tenant filter is now the SOLE leak boundary; search_path is pinned to 'public' as required
-- for any DEFINER function. Body is otherwise byte-for-byte the 20260716073759 original.
-- Do NOT revert to SECURITY INVOKER — that reintroduces the tombstone strip.
create or replace function public.sync_pull_reference(p_since timestamptz default null)
returns jsonb language plpgsql security definer set search_path to 'public' stable as $$
declare
  v_tenant    uuid        := public.auth_tenant_id();
  v_since     timestamptz := coalesce(p_since, '-infinity'::timestamptz);
  -- 2s margin: a txn committing at T-1ms but invisible to our snapshot would be skipped FOREVER by a now()
  -- watermark. Re-delivers <=2s of rows; the client upserts by id, so re-delivery is a no-op. Cheaper to
  -- build in now than to debug later as "one product occasionally never syncs".
  v_watermark timestamptz := now() - interval '2 seconds';
begin
  if v_tenant is null then raise exception 'ERR_NO_TENANT'; end if;
  return jsonb_build_object(
    'watermark', v_watermark,
    -- Explicit column lists (reconciled to D11.1 live, NOT the doc). to_jsonb(t) would weld the client model
    -- to whatever the table happens to be and ship cost_price to every cashier's device.
    'products', coalesce((select jsonb_agg(jsonb_build_object(
        'id',p.id,'sku',p.sku,'name',p.name,'barcode',p.barcode,'type',p.type,'category_id',p.category_id,
        'brand_id',p.brand_id,'unit_of_measure',p.unit_of_measure,'selling_price',p.selling_price,
        'min_selling_price',p.min_selling_price,'tax_rate',p.tax_rate,'tax_inclusive',p.tax_inclusive,
        'is_active',p.is_active,'status',p.status,'image_url',p.image_url,'updated_at',p.updated_at,
        'deleted_at',p.deleted_at) order by p.updated_at)
      from products p where p.tenant_id=v_tenant and p.updated_at>v_since and p.updated_at<=v_watermark),'[]'::jsonb),
      -- NOTE: cost_price/wholesale_price DELIBERATELY omitted — the POS never needs them offline.
    'variants', coalesce((select jsonb_agg(jsonb_build_object(
        'id',v.id,'product_id',v.product_id,'variant_name',v.variant_name,'sku',v.sku,'barcode',v.barcode,
        'selling_price',v.selling_price,'attributes_json',v.attributes_json,'is_active',v.is_active,
        'updated_at',v.updated_at,'deleted_at',v.deleted_at) order by v.updated_at)
      from product_variants v join products p2 on p2.id=v.product_id
      where p2.tenant_id=v_tenant and v.updated_at>v_since and v.updated_at<=v_watermark),'[]'::jsonb),
      -- product_variants has NO tenant_id (D11.1) -> scoped through its parent product.
    'customers', coalesce((select jsonb_agg(jsonb_build_object(
        'id',c.id,'name',c.name,'phone',c.phone,'email',c.email,'credit_limit',c.credit_limit,
        'credit_terms',c.credit_terms,'status',c.status,'updated_at',c.updated_at,'deleted_at',c.deleted_at)
        order by c.updated_at)
      from customers c where c.tenant_id=v_tenant and c.updated_at>v_since and c.updated_at<=v_watermark),'[]'::jsonb),
    'payment_methods', coalesce((select jsonb_agg(jsonb_build_object(
        'id',m.id,'name',m.name,'code',m.code,'is_active',m.is_active,'requires_reference',m.requires_reference,
        'sort_order',m.sort_order,'updated_at',m.updated_at,'deleted_at',m.deleted_at) order by m.sort_order)
      from payment_methods m where m.tenant_id=v_tenant and m.updated_at>v_since and m.updated_at<=v_watermark),'[]'::jsonb),
    'tax_rules', coalesce((select jsonb_agg(jsonb_build_object(
        'id',t.id,'name',t.name,'code',t.code,'rate',t.rate,'mode',t.mode,'is_default',t.is_default,
        'applies_to',t.applies_to,'is_active',t.is_active,'effective_from',t.effective_from,
        'effective_until',t.effective_until,'updated_at',t.updated_at,'deleted_at',t.deleted_at) order by t.updated_at)
      from tax_rules t where t.tenant_id=v_tenant and t.updated_at>v_since and t.updated_at<=v_watermark),'[]'::jsonb),
    -- ===== stock_balance: FULL PULL, NOT WATERMARKED (Load-bearing fact #2) =====
    -- It has last_updated (not updated_at) and NO deleted_at. Advisory-only in the cache, small per branch,
    -- trigger-created and never deleted. Full pull can't drift; a special-cased watermark can.
    'stock_full', true,
    'stock', coalesce((select jsonb_agg(jsonb_build_object(
        'product_id',s.product_id,'variant_id',s.variant_id,'branch_id',s.branch_id,
        'qty_on_hand',s.qty_on_hand,'qty_reserved',s.qty_reserved,'last_updated',s.last_updated))
      from stock_balance s where s.tenant_id=v_tenant and s.warehouse_id is null),'[]'::jsonb)
      -- warehouse_id IS NULL = canonical stock (the M08 D1 filter — avoids variant/warehouse fan-out).
  );
end; $$;
