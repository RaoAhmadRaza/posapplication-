-- ========== ENUMS (guarded; stock_movement_type_enum + number_series_type_enum already exist) ==========
do $$ begin
  create type supplier_status_enum as enum ('ACTIVE','INACTIVE','BLACKLISTED');
exception when duplicate_object then null; end $$;

do $$ begin
  create type purchase_order_status_enum as enum
    ('DRAFT','SUBMITTED','APPROVED','PARTIALLY_RECEIVED','RECEIVED','INVOICED','CLOSED','CANCELLED');
exception when duplicate_object then null; end $$;

do $$ begin
  create type purchase_invoice_status_enum as enum ('DRAFT','PENDING','APPROVED','PAID','VOID');
exception when duplicate_object then null; end $$;

-- ========== SUPPLIERS (verbatim DATABASE_SCHEMA.md §3.8) ==========
create table if not exists public.suppliers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name varchar(255) not null,
  contact_person varchar(255),
  phone varchar(50),
  email varchar(255),
  address_line1 varchar(255),
  address_line2 varchar(255),
  city varchar(100),
  state varchar(100),
  postal_code varchar(20),
  country varchar(100) default 'Pakistan',
  tax_number varchar(50),
  payment_terms integer not null default 30,
  currency varchar(3) not null default 'PKR',
  bank_name varchar(255),
  bank_account_number varchar(100),
  opening_balance decimal(15,4) not null default 0,
  status supplier_status_enum not null default 'ACTIVE',
  tags text[],
  custom_fields_json jsonb default '{}'::jsonb,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  version integer not null default 1,
  created_by uuid references public.users(id),
  updated_by uuid references public.users(id)
);

create index if not exists idx_suppliers_tenant_name  on public.suppliers(tenant_id, name)  where deleted_at is null;
create index if not exists idx_suppliers_tenant_phone on public.suppliers(tenant_id, phone) where deleted_at is null;
create index if not exists idx_suppliers_status       on public.suppliers(tenant_id, status) where deleted_at is null;

-- updated_at bump (reuse existing generic touch fn if present; else create)
do $$ begin
  create or replace function public.fn_touch_updated_at() returns trigger language plpgsql as $f$
  begin new.updated_at = now(); return new; end $f$;
exception when others then null; end $$;

drop trigger if exists trg_suppliers_touch on public.suppliers;
create trigger trg_suppliers_touch before update on public.suppliers
  for each row execute function public.fn_touch_updated_at();

-- RLS: tenant-scoped read; mutations gated on purchase perms (mirrors the customers pattern)
alter table public.suppliers enable row level security;

drop policy if exists "suppliers tenant read" on public.suppliers;
create policy "suppliers tenant read" on public.suppliers
  for select to authenticated using (tenant_id = public.auth_tenant_id());

drop policy if exists "suppliers gated insert" on public.suppliers;
create policy "suppliers gated insert" on public.suppliers
  for insert to authenticated
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('purchase','create'));

drop policy if exists "suppliers gated update" on public.suppliers;
create policy "suppliers gated update" on public.suppliers
  for update to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('purchase','update'))
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('purchase','update'));

-- (no client delete policy: soft-delete via UPDATE deleted_at, covered by the update policy +
--  purchase:delete enforced in the app; hard delete blocked)

-- ========== PERMISSION MODULE: purchase ==========
-- Backfill every existing ADMIN role. branch_scope 'ALL' matches the seeded ADMIN matrix.
insert into public.permissions (role_id, module, action, branch_scope, granted)
select r.id, 'purchase', a.action, 'ALL', true
from public.roles r
cross join (values ('read'),('create'),('update'),('delete'),('approve'),('export')) as a(action)
where r.name = 'ADMIN'
on conflict (role_id, module, action) do nothing;

-- Future tenants: seed purchase perms whenever a new ADMIN role is created (idempotent).
create or replace function public.seed_purchase_perms_for_admin()
returns trigger language plpgsql security definer set search_path to 'public' as $f$
begin
  if NEW.name = 'ADMIN' then
    insert into public.permissions (role_id, module, action, branch_scope, granted)
    select NEW.id, 'purchase', a.action, 'ALL', true
    from (values ('read'),('create'),('update'),('delete'),('approve'),('export')) as a(action)
    on conflict (role_id, module, action) do nothing;
  end if;
  return NEW;
end $f$;

drop trigger if exists trg_seed_purchase_perms on public.roles;
create trigger trg_seed_purchase_perms after insert on public.roles
  for each row execute function public.seed_purchase_perms_for_admin();

-- ========== NUMBER SERIES SEEDS (PURCHASE_ORDER, GRN, PAYMENT_VOUCHER) for all tenants ==========
-- next_number auto-creates a row if missing, but with empty prefix; seed to get PO-/GRN-/PV- prefixes.
-- padding omitted → inherits table default (6), so numbers render PO-000001 / GRN-000001 / PV-000001.
insert into public.number_series (tenant_id, branch_id, type, prefix, current_number)
select t.id, null, v.type::number_series_type_enum, v.prefix, 0
from public.tenants t
cross join (values
  ('PURCHASE_ORDER','PO-'),
  ('GRN','GRN-'),
  ('PAYMENT_VOUCHER','PV-')
) as v(type, prefix)
where not exists (
  select 1 from public.number_series ns
  where ns.tenant_id = t.id
    and ns.type = v.type::number_series_type_enum
    and ns.branch_id is null
);