-- 20260611163739_product_sku_and_search.sql
-- (1) pg_trgm extension + GIN trigram indexes for fast ILIKE substring search
-- (2) SKU auto-generation: sequence table + function + BEFORE INSERT trigger
-- (3) RPC for product substring search (replaces unreliable FTS + .or() % encoding)
-- Applies on top of 20260611000001_product_catalog.sql.

-- ===== Trigram indexes for ILIKE substring search =====
create extension if not exists pg_trgm;

create index if not exists idx_products_name_trgm
  on public.products using gin (name gin_trgm_ops);

create index if not exists idx_products_sku_trgm
  on public.products using gin (sku gin_trgm_ops);

create index if not exists idx_products_barcode_trgm
  on public.products using gin (barcode gin_trgm_ops) where barcode is not null;

-- ===== SKU auto-generation sequence table =====
create table if not exists public.product_sku_sequences (
    tenant_id uuid primary key references public.tenants(id),
    last_number integer not null default 0
);

-- ===== SKU generator function (atomic via UPDATE ... RETURNING row lock) =====
create or replace function public.next_product_sku(p_tenant uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
    v_num integer;
begin
    insert into public.product_sku_sequences (tenant_id, last_number)
    values (p_tenant, 0)
    on conflict (tenant_id) do nothing;

    update public.product_sku_sequences
    set last_number = last_number + 1
    where tenant_id = p_tenant
    returning last_number into v_num;

    return 'PRD-' || lpad(v_num::text, 6, '0');
end;
$$;

grant execute on function public.next_product_sku(uuid) to authenticated;

-- ===== SKU assign trigger (auto-fills SKU on INSERT when null/empty) =====
create or replace function public.trg_product_assign_sku()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    if new.sku is null or new.sku = '' then
        new.sku := public.next_product_sku(new.tenant_id);
    end if;
    return new;
end;
$$;

drop trigger if exists trg_product_before_insert_sku on public.products;
create trigger trg_product_before_insert_sku
    before insert on public.products
    for each row
    execute function public.trg_product_assign_sku();

-- ===== Search RPC (security invoker — respects RLS; trigram-accelerated ILIKE) =====
create or replace function public.search_products(p_query text)
returns setof public.products
language sql
security invoker
stable
as $$
    select * from public.products
    where deleted_at is null
      and (
        name ilike '%' || p_query || '%'
        or sku ilike '%' || p_query || '%'
        or barcode ilike p_query
      )
    order by created_at desc;
$$;
