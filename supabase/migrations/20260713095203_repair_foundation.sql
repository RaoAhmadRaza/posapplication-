-- repair_status_enum — verbatim §3.11 (schema line 196). Must exist before the tables.
-- CREATE TYPE (unlike ALTER TYPE ADD VALUE) can be created AND used in the same migration.
do $$ begin
  create type public.repair_status_enum as enum
    ('RECEIVED','DIAGNOSED','AWAITING_APPROVAL','IN_REPAIR','QC','READY','DELIVERED','WARRANTY_CLAIM','CANCELLED');
exception when duplicate_object then null;
end $$;

-- ========== repair_jobs — verbatim §3.11 ==========
create table if not exists public.repair_jobs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid not null references public.branches(id),
  customer_id uuid not null references public.customers(id),
  job_number varchar(50) not null,
  device_type varchar(100) not null,
  device_brand varchar(100),
  device_model varchar(100),
  serial_no varchar(100),
  imei varchar(50),
  reported_issue text not null,
  diagnosis text,
  technician_id uuid references public.users(id),
  status repair_status_enum not null default 'RECEIVED',
  priority varchar(20) not null default 'NORMAL',
  estimated_cost decimal(15,4),
  final_cost decimal(15,4),
  customer_approved boolean,
  invoice_id uuid references public.invoices(id),
  warranty_expires_at date,
  received_at timestamptz not null default now(),
  delivered_at timestamptz,
  customer_signature_url varchar(500),
  notes text,
  correlation_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  version integer not null default 1,
  created_by uuid references public.users(id),
  updated_by uuid references public.users(id)
);
create unique index if not exists uq_repair_jobs_tenant_number on public.repair_jobs(tenant_id, job_number) where deleted_at is null;
create index if not exists idx_repair_jobs_branch_status on public.repair_jobs(branch_id, status) where deleted_at is null;
create index if not exists idx_repair_jobs_customer on public.repair_jobs(customer_id) where deleted_at is null;
create index if not exists idx_repair_jobs_technician on public.repair_jobs(technician_id) where deleted_at is null and technician_id is not null;
create index if not exists idx_repair_jobs_status on public.repair_jobs(tenant_id, status) where deleted_at is null;

-- ========== repair_parts — verbatim §3.11 ==========
create table if not exists public.repair_parts (
  id uuid primary key default gen_random_uuid(),
  repair_id uuid not null references public.repair_jobs(id) on delete cascade,
  product_id uuid not null references public.products(id),
  qty decimal(15,4) not null,
  unit_cost decimal(15,4) not null,
  total_cost decimal(15,4) not null,
  stock_ledger_id uuid references public.stock_ledger(id),
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references public.users(id)
);
create index if not exists idx_repair_parts_repair on public.repair_parts(repair_id);
create index if not exists idx_repair_parts_product on public.repair_parts(product_id);
do $$ begin alter table public.repair_parts add constraint chk_repair_parts_qty check (qty > 0); exception when duplicate_object then null; end $$;

-- ========== repair_status_history — verbatim §3.11 ==========
create table if not exists public.repair_status_history (
  id uuid primary key default gen_random_uuid(),
  repair_id uuid not null references public.repair_jobs(id) on delete cascade,
  old_status repair_status_enum,
  new_status repair_status_enum not null,
  changed_by uuid not null references public.users(id),
  changed_at timestamptz not null default now(),
  notes text
);
create index if not exists idx_repair_status_history_repair on public.repair_status_history(repair_id, changed_at);

-- ========== RLS ==========
alter table public.repair_jobs enable row level security;
drop policy if exists "rj tenant read" on public.repair_jobs;
create policy "rj tenant read" on public.repair_jobs for select to authenticated using (tenant_id = public.auth_tenant_id());
drop policy if exists "rj gated insert" on public.repair_jobs;
create policy "rj gated insert" on public.repair_jobs for insert to authenticated
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('repair','create'));
drop policy if exists "rj gated update" on public.repair_jobs;
create policy "rj gated update" on public.repair_jobs for update to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('repair','update'))
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('repair','update'));

alter table public.repair_parts enable row level security;
drop policy if exists "rp tenant read" on public.repair_parts;
create policy "rp tenant read" on public.repair_parts for select to authenticated using (
  exists (select 1 from public.repair_jobs j where j.id=repair_id and j.tenant_id=public.auth_tenant_id()));
revoke insert, update, delete on public.repair_parts from authenticated;   -- via add_repair_part RPC only

alter table public.repair_status_history enable row level security;
drop policy if exists "rsh tenant read" on public.repair_status_history;
create policy "rsh tenant read" on public.repair_status_history for select to authenticated using (
  exists (select 1 from public.repair_jobs j where j.id=repair_id and j.tenant_id=public.auth_tenant_id()));
revoke insert, update, delete on public.repair_status_history from authenticated;   -- via change_repair_status RPC only

-- ========== PERMISSION MODULE: repair (same pattern as purchase/accounting) ==========
insert into public.permissions (role_id, module, action, branch_scope, granted)
select r.id, 'repair', a.action, 'ALL', true
from public.roles r
cross join (values ('read'),('create'),('update'),('delete'),('approve'),('export')) as a(action)
where r.name = 'ADMIN'
on conflict (role_id, module, action) do nothing;

create or replace function public.seed_repair_perms_for_admin()
returns trigger language plpgsql security definer set search_path to 'public' as $f$
begin
  if NEW.name = 'ADMIN' then
    insert into public.permissions (role_id, module, action, branch_scope, granted)
    select NEW.id, 'repair', a.action, 'ALL', true
    from (values ('read'),('create'),('update'),('delete'),('approve'),('export')) as a(action)
    on conflict (role_id, module, action) do nothing;
  end if;
  return NEW;
end $f$;
drop trigger if exists trg_seed_repair_perms on public.roles;
create trigger trg_seed_repair_perms after insert on public.roles
  for each row execute function public.seed_repair_perms_for_admin();

-- ========== NUMBER SERIES (REPAIR_JOB → RJ-) all tenants (idempotent re-confirm) ==========
insert into public.number_series (tenant_id, branch_id, type, prefix, current_number)
select t.id, null, 'REPAIR_JOB'::number_series_type_enum, 'RJ-', 0
from public.tenants t
where not exists (select 1 from public.number_series ns
  where ns.tenant_id=t.id and ns.type='REPAIR_JOB'::number_series_type_enum and ns.branch_id is null);

-- ========== SEED: sentinel "Repair Service" product per tenant (labour line target) ==========
-- product_id is NOT NULL on invoice_items, so labour can't post without a product row. type='SERVICE' is
-- the non-stock signal (no track_inventory column exists) → it is never GRN'd/counted/stock-moved.
-- Only tenant_id/sku/name are NOT-NULL-without-default; type overridden to SERVICE explicitly. Valid as-is.
insert into public.products (tenant_id, sku, name, type, is_active)
select t.id, 'REPAIR-SERVICE', 'Repair Service', 'SERVICE', true
from public.tenants t
where not exists (select 1 from public.products p where p.tenant_id=t.id and p.sku='REPAIR-SERVICE');

-- helper: resolve the sentinel product id for a tenant (used by close_repair_job labour line)
create or replace function public.repair_service_product(p_tenant uuid)
returns uuid language sql stable security definer set search_path to 'public' as $$
  select id from public.products where tenant_id=p_tenant and sku='REPAIR-SERVICE' and deleted_at is null limit 1;
$$;

-- ========== SEED: 4200 Service Revenue per tenant (flat live CoA has no service line) ==========
-- parent_id left NULL to match the flat live CoA (codes 1000–6100). If your live CoA is hierarchical,
-- set parent_id = public.acct_id(t.id,'4000').
insert into public.accounts (tenant_id, code, name, type, is_system)
select t.id, '4200', 'Service Revenue', 'REVENUE', true
from public.tenants t
where not exists (select 1 from public.accounts a where a.tenant_id=t.id and a.code='4200' and a.deleted_at is null);