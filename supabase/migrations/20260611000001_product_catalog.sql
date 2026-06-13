-- 20260611000000_product_catalog.sql
-- Slice A — Product Catalog (schema doc §3.4) on Supabase.
-- Applies on top of the three auth migrations. Additive + idempotent + ordered.
-- Tenant isolation via auth_tenant_id(); writes gated by the 'inventory' permission matrix
-- using a new auth_has_permission(module, action) helper.

-- ===== Enums (guarded) =====
do $$ begin create type product_type_enum   as enum ('STANDARD','SERIALIZED','SERVICE','COMPOSITE'); exception when duplicate_object then null; end $$;
do $$ begin create type product_status_enum as enum ('ACTIVE','INACTIVE','DISCONTINUED');            exception when duplicate_object then null; end $$;

-- ===== Permission helper (reusable across ALL future modules) =====
-- Returns true if the signed-in user's role grants module:action (granted = true).
create or replace function public.auth_has_permission(p_module text, p_action text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1
    from public.permissions p
    join public.users u on u.role_id = p.role_id
    where u.id = auth.uid()
      and p.module  = p_module
      and p.action  = p_action
      and p.granted = true
  );
$$;

-- ===== Shared row triggers =====
-- Bump-only version (NOT the spec's strict optimistic-lock reject — see DECISIONS).
-- Auto-sets updated_at and increments version on every UPDATE. App need not send version.
create or replace function public.fn_touch_row()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  new.version    := old.version + 1;
  return new;
end; $$;

-- updated_at only, for tables without a version column.
create or replace function public.fn_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end; $$;

-- ===== Products full-text search vector (schema doc §9.7) =====
create or replace function public.fn_products_search_vector()
returns trigger language plpgsql as $$
begin
  new.search_vector :=
    setweight(to_tsvector('english', coalesce(new.name, '')),        'A') ||
    setweight(to_tsvector('english', coalesce(new.sku, '')),         'A') ||
    setweight(to_tsvector('english', coalesce(new.barcode, '')),     'B') ||
    setweight(to_tsvector('english', coalesce(new.description, '')), 'C') ||
    setweight(to_tsvector('english', coalesce((select name from public.brands     where id = new.brand_id),    '')), 'C') ||
    setweight(to_tsvector('english', coalesce((select name from public.categories where id = new.category_id), '')), 'C');
  return new;
end; $$;

-- ===== categories (self-referencing tree) =====
create table if not exists public.categories (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.tenants(id),
  name        varchar(255) not null,
  slug        varchar(255) not null,
  parent_id   uuid references public.categories(id),
  description text,
  image_url   varchar(500),
  sort_order  integer not null default 0,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  version     integer not null default 1,
  created_by  uuid references public.users(id),
  updated_by  uuid references public.users(id)
);
create unique index if not exists uq_categories_tenant_slug on public.categories(tenant_id, slug) where deleted_at is null;
create index        if not exists idx_categories_parent     on public.categories(parent_id)        where deleted_at is null;
create index        if not exists idx_categories_tenant     on public.categories(tenant_id)         where deleted_at is null;

-- ===== brands =====
create table if not exists public.brands (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.tenants(id),
  name        varchar(255) not null,
  slug        varchar(255) not null,
  logo_url    varchar(500),
  description text,
  is_active   boolean not null default true,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz,
  version     integer not null default 1,
  created_by  uuid references public.users(id),
  updated_by  uuid references public.users(id)
);
create unique index if not exists uq_brands_tenant_slug on public.brands(tenant_id, slug) where deleted_at is null;
create index        if not exists idx_brands_tenant     on public.brands(tenant_id)       where deleted_at is null;

-- ===== products =====
create table if not exists public.products (
  id                 uuid primary key default gen_random_uuid(),
  tenant_id          uuid not null references public.tenants(id),
  sku                varchar(100) not null,
  name               varchar(500) not null,
  description        text,
  barcode            varchar(100),
  type               product_type_enum not null default 'STANDARD',
  category_id        uuid references public.categories(id),
  brand_id           uuid references public.brands(id),
  unit_of_measure    varchar(50)  not null default 'PCS',
  cost_price         decimal(15,4) not null default 0,
  selling_price      decimal(15,4) not null default 0,
  min_selling_price  decimal(15,4),
  wholesale_price    decimal(15,4),
  tax_rate           decimal(5,2)  not null default 0,
  tax_inclusive      boolean       not null default false,
  reorder_point      integer       not null default 0,
  reorder_qty        integer       not null default 0,
  weight             decimal(10,3),
  is_active          boolean       not null default true,
  status             product_status_enum not null default 'ACTIVE',
  image_url          varchar(500),
  tags               text[],
  custom_fields_json jsonb default '{}'::jsonb,
  search_vector      tsvector,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  deleted_at         timestamptz,
  version            integer not null default 1,
  created_by         uuid references public.users(id),
  updated_by         uuid references public.users(id)
);
create unique index if not exists uq_products_tenant_sku      on public.products(tenant_id, sku)      where deleted_at is null;
create unique index if not exists uq_products_tenant_barcode  on public.products(tenant_id, barcode)  where deleted_at is null and barcode is not null;
create index        if not exists idx_products_tenant_category on public.products(tenant_id, category_id) where deleted_at is null;
create index        if not exists idx_products_tenant_brand    on public.products(tenant_id, brand_id)    where deleted_at is null;
create index        if not exists idx_products_tenant_status   on public.products(tenant_id, status)      where deleted_at is null;
create index        if not exists idx_products_search          on public.products using gin(search_vector);
create index        if not exists idx_products_tags            on public.products using gin(tags)         where deleted_at is null;

-- ===== product_variants =====
create table if not exists public.product_variants (
  id              uuid primary key default gen_random_uuid(),
  product_id      uuid not null references public.products(id) on delete cascade,
  variant_name    varchar(255) not null,
  sku             varchar(100) not null,
  barcode         varchar(100),
  cost_price      decimal(15,4) not null default 0,
  selling_price   decimal(15,4) not null default 0,
  weight          decimal(10,3),
  attributes_json jsonb not null default '{}'::jsonb,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,
  version         integer not null default 1
);
create unique index if not exists uq_product_variants_sku on public.product_variants(sku)        where deleted_at is null;
create index        if not exists idx_product_variants_product on public.product_variants(product_id) where deleted_at is null;

-- ===== product_images =====
create table if not exists public.product_images (
  id         uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  url        varchar(500) not null,
  alt_text   varchar(255),
  sort_order integer not null default 0,
  is_primary boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists idx_product_images_product on public.product_images(product_id);

-- ===== product_pricing_tiers =====
-- NOTE: customer_group_id is a plain nullable uuid here (no FK) — customer_groups arrives in the
-- CRM slice; a forward migration will add the FK then.
create table if not exists public.product_pricing_tiers (
  id                uuid primary key default gen_random_uuid(),
  product_id        uuid not null references public.products(id) on delete cascade,
  tier_name         varchar(100) not null,
  customer_group_id uuid,
  min_qty           integer not null default 1,
  max_qty           integer,
  unit_price        decimal(15,4) not null,
  discount_pct      decimal(5,2),
  valid_from        date,
  valid_until       date,
  is_active         boolean not null default true,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index if not exists idx_pricing_tiers_product on public.product_pricing_tiers(product_id);
create index if not exists idx_pricing_tiers_group   on public.product_pricing_tiers(customer_group_id) where customer_group_id is not null;

-- ===== barcode_templates =====
create table if not exists public.barcode_templates (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null references public.tenants(id),
  name        varchar(255) not null,
  format      varchar(50)  not null default 'CODE128',
  width_mm    integer not null default 50,
  height_mm   integer not null default 25,
  layout_json jsonb   not null default '{}'::jsonb,
  is_default  boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  deleted_at  timestamptz
);
create index if not exists idx_barcode_templates_tenant on public.barcode_templates(tenant_id) where deleted_at is null;

-- ===== Triggers: updated_at / version =====
drop trigger if exists trg_categories_touch        on public.categories;
create trigger trg_categories_touch        before update on public.categories        for each row execute function public.fn_touch_row();
drop trigger if exists trg_brands_touch            on public.brands;
create trigger trg_brands_touch            before update on public.brands            for each row execute function public.fn_touch_row();
drop trigger if exists trg_products_touch          on public.products;
create trigger trg_products_touch          before update on public.products          for each row execute function public.fn_touch_row();
drop trigger if exists trg_product_variants_touch  on public.product_variants;
create trigger trg_product_variants_touch  before update on public.product_variants  for each row execute function public.fn_touch_row();
drop trigger if exists trg_pricing_tiers_touch     on public.product_pricing_tiers;
create trigger trg_pricing_tiers_touch     before update on public.product_pricing_tiers for each row execute function public.fn_set_updated_at();
drop trigger if exists trg_barcode_templates_touch on public.barcode_templates;
create trigger trg_barcode_templates_touch before update on public.barcode_templates for each row execute function public.fn_set_updated_at();

-- ===== Trigger: products search_vector =====
drop trigger if exists trg_products_search_vector on public.products;
create trigger trg_products_search_vector
  before insert or update of name, sku, barcode, description, brand_id, category_id
  on public.products for each row execute function public.fn_products_search_vector();

-- ===== RLS =====
-- Pattern per tenant-scoped table: read = tenant members (active rows); writes gated by the
-- 'inventory' permission matrix via auth_has_permission(). Soft-delete is an UPDATE of deleted_at,
-- so it travels through the UPDATE policy (UI gates the delete action with inventory:delete).

-- categories
alter table public.categories enable row level security;
drop policy if exists "categories read"   on public.categories;
create policy "categories read"   on public.categories for select to authenticated using (tenant_id = public.auth_tenant_id() and deleted_at is null);
drop policy if exists "categories insert" on public.categories;
create policy "categories insert" on public.categories for insert to authenticated with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('inventory','create'));
drop policy if exists "categories update" on public.categories;
create policy "categories update" on public.categories for update to authenticated using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('inventory','update')) with check (tenant_id = public.auth_tenant_id());

-- brands
alter table public.brands enable row level security;
drop policy if exists "brands read"   on public.brands;
create policy "brands read"   on public.brands for select to authenticated using (tenant_id = public.auth_tenant_id() and deleted_at is null);
drop policy if exists "brands insert" on public.brands;
create policy "brands insert" on public.brands for insert to authenticated with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('inventory','create'));
drop policy if exists "brands update" on public.brands;
create policy "brands update" on public.brands for update to authenticated using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('inventory','update')) with check (tenant_id = public.auth_tenant_id());

-- products
alter table public.products enable row level security;
drop policy if exists "products read"   on public.products;
create policy "products read"   on public.products for select to authenticated using (tenant_id = public.auth_tenant_id() and deleted_at is null);
drop policy if exists "products insert" on public.products;
create policy "products insert" on public.products for insert to authenticated with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('inventory','create'));
drop policy if exists "products update" on public.products;
create policy "products update" on public.products for update to authenticated using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('inventory','update')) with check (tenant_id = public.auth_tenant_id());

-- product_variants (tenant inherited from parent product)
alter table public.product_variants enable row level security;
drop policy if exists "variants read"   on public.product_variants;
create policy "variants read"   on public.product_variants for select to authenticated using (exists (select 1 from public.products p where p.id = product_variants.product_id and p.tenant_id = public.auth_tenant_id()) and deleted_at is null);
drop policy if exists "variants insert" on public.product_variants;
create policy "variants insert" on public.product_variants for insert to authenticated with check (exists (select 1 from public.products p where p.id = product_variants.product_id and p.tenant_id = public.auth_tenant_id()) and public.auth_has_permission('inventory','create'));
drop policy if exists "variants update" on public.product_variants;
create policy "variants update" on public.product_variants for update to authenticated using (exists (select 1 from public.products p where p.id = product_variants.product_id and p.tenant_id = public.auth_tenant_id()) and public.auth_has_permission('inventory','update'));

-- product_images
alter table public.product_images enable row level security;
drop policy if exists "images read"   on public.product_images;
create policy "images read"   on public.product_images for select to authenticated using (exists (select 1 from public.products p where p.id = product_images.product_id and p.tenant_id = public.auth_tenant_id()));
drop policy if exists "images write"  on public.product_images;
create policy "images write"  on public.product_images for all to authenticated using (exists (select 1 from public.products p where p.id = product_images.product_id and p.tenant_id = public.auth_tenant_id()) and public.auth_has_permission('inventory','update')) with check (exists (select 1 from public.products p where p.id = product_images.product_id and p.tenant_id = public.auth_tenant_id()));

-- product_pricing_tiers
alter table public.product_pricing_tiers enable row level security;
drop policy if exists "pricing read"  on public.product_pricing_tiers;
create policy "pricing read"  on public.product_pricing_tiers for select to authenticated using (exists (select 1 from public.products p where p.id = product_pricing_tiers.product_id and p.tenant_id = public.auth_tenant_id()));
drop policy if exists "pricing write" on public.product_pricing_tiers;
create policy "pricing write" on public.product_pricing_tiers for all to authenticated using (exists (select 1 from public.products p where p.id = product_pricing_tiers.product_id and p.tenant_id = public.auth_tenant_id()) and public.auth_has_permission('inventory','update')) with check (exists (select 1 from public.products p where p.id = product_pricing_tiers.product_id and p.tenant_id = public.auth_tenant_id()));

-- barcode_templates
alter table public.barcode_templates enable row level security;
drop policy if exists "barcode read"  on public.barcode_templates;
create policy "barcode read"  on public.barcode_templates for select to authenticated using (tenant_id = public.auth_tenant_id() and deleted_at is null);
drop policy if exists "barcode write" on public.barcode_templates;
create policy "barcode write" on public.barcode_templates for all to authenticated using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('inventory','update')) with check (tenant_id = public.auth_tenant_id());