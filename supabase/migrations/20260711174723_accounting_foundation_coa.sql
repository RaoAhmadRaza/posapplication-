-- ========== ENUMS (schema §, guarded; most already exist per A0.2) ==========
do $$ begin create type account_type_enum as enum ('ASSET','LIABILITY','EQUITY','REVENUE','EXPENSE'); exception when duplicate_object then null; end $$;
do $$ begin create type fiscal_period_status_enum as enum ('OPEN','CLOSED','LOCKED'); exception when duplicate_object then null; end $$;
do $$ begin create type voucher_type_enum as enum ('PAYMENT','RECEIPT','CONTRA','JOURNAL'); exception when duplicate_object then null; end $$;
do $$ begin create type reconciliation_status_enum as enum ('DRAFT','IN_PROGRESS','COMPLETED'); exception when duplicate_object then null; end $$;
do $$ begin create type entity_type_enum as enum ('CUSTOMER','SUPPLIER'); exception when duplicate_object then null; end $$;
do $$ begin create type tax_calculation_mode_enum as enum ('INCLUSIVE','EXCLUSIVE'); exception when duplicate_object then null; end $$;

-- ========== accounts (chart of accounts) — verbatim §3.9 ==========
create table if not exists public.accounts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  code varchar(20) not null,
  name varchar(255) not null,
  type account_type_enum not null,
  parent_id uuid references public.accounts(id),
  description text,
  is_system boolean not null default false,
  is_active boolean not null default true,
  branch_id uuid references public.branches(id),
  opening_balance decimal(15,4) not null default 0,
  current_balance decimal(15,4) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  version integer not null default 1,
  created_by uuid references public.users(id),
  updated_by uuid references public.users(id)
);
create unique index if not exists uq_accounts_tenant_code on public.accounts(tenant_id, code) where deleted_at is null;
create index if not exists idx_accounts_parent on public.accounts(parent_id) where deleted_at is null;
create index if not exists idx_accounts_type on public.accounts(tenant_id, type) where deleted_at is null;
create index if not exists idx_accounts_branch on public.accounts(tenant_id, branch_id) where deleted_at is null;

-- ========== fiscal_periods — verbatim §3.9 ==========
create table if not exists public.fiscal_periods (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name varchar(100) not null,
  start_date date not null,
  end_date date not null,
  status fiscal_period_status_enum not null default 'OPEN',
  closed_by uuid references public.users(id),
  closed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_fiscal_periods_tenant on public.fiscal_periods(tenant_id, start_date);
create index if not exists idx_fiscal_periods_status on public.fiscal_periods(tenant_id, status);
do $$ begin alter table public.fiscal_periods add constraint chk_fiscal_periods_dates check (end_date > start_date); exception when duplicate_object then null; end $$;

-- ========== tax_rules — verbatim §3.14 ==========
create table if not exists public.tax_rules (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name varchar(100) not null,
  code varchar(20) not null,
  rate decimal(5,2) not null,
  mode tax_calculation_mode_enum not null default 'EXCLUSIVE',
  is_default boolean not null default false,
  applies_to varchar(50) not null default 'ALL',
  description text,
  is_active boolean not null default true,
  effective_from date,
  effective_until date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index if not exists uq_tax_rules_tenant_code on public.tax_rules(tenant_id, code) where deleted_at is null;
create index if not exists idx_tax_rules_active on public.tax_rules(tenant_id) where is_active = true and deleted_at is null;

-- ========== ledger_accounts (AR/AP running balance) — verbatim §3.8 ==========
create table if not exists public.ledger_accounts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  entity_type entity_type_enum not null,
  entity_id uuid not null,
  balance decimal(15,4) not null default 0,
  credit_limit decimal(15,4) not null default 0,
  last_transaction_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists uq_ledger_accounts_entity on public.ledger_accounts(tenant_id, entity_type, entity_id);
create index if not exists idx_ledger_accounts_entity on public.ledger_accounts(entity_id);
create index if not exists idx_ledger_accounts_balance on public.ledger_accounts(tenant_id, entity_type) where balance != 0;

-- ========== RLS ==========
-- accounts/fiscal_periods/tax_rules/ledger_accounts: tenant read; writes via RPC (except tax_rules client-CRUD)
alter table public.accounts enable row level security;
drop policy if exists "accounts tenant read" on public.accounts;
create policy "accounts tenant read" on public.accounts for select to authenticated using (tenant_id = public.auth_tenant_id());
revoke insert, update, delete on public.accounts from authenticated;

alter table public.fiscal_periods enable row level security;
drop policy if exists "fp tenant read" on public.fiscal_periods;
create policy "fp tenant read" on public.fiscal_periods for select to authenticated using (tenant_id = public.auth_tenant_id());
revoke insert, update, delete on public.fiscal_periods from authenticated;

alter table public.ledger_accounts enable row level security;
drop policy if exists "la tenant read" on public.ledger_accounts;
create policy "la tenant read" on public.ledger_accounts for select to authenticated using (tenant_id = public.auth_tenant_id());
revoke insert, update, delete on public.ledger_accounts from authenticated;

alter table public.tax_rules enable row level security;
drop policy if exists "tax tenant read" on public.tax_rules;
create policy "tax tenant read" on public.tax_rules for select to authenticated using (tenant_id = public.auth_tenant_id());
drop policy if exists "tax gated insert" on public.tax_rules;
create policy "tax gated insert" on public.tax_rules for insert to authenticated
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('accounting','create'));
drop policy if exists "tax gated update" on public.tax_rules;
create policy "tax gated update" on public.tax_rules for update to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('accounting','update'))
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('accounting','update'));

-- ========== PERMISSION MODULE: accounting (same pattern as 'purchase') ==========
insert into public.permissions (role_id, module, action, branch_scope, granted)
select r.id, 'accounting', a.action, 'ALL', true
from public.roles r
cross join (values ('read'),('create'),('update'),('delete'),('approve'),('export')) as a(action)
where r.name = 'ADMIN'
on conflict (role_id, module, action) do nothing;

create or replace function public.seed_accounting_perms_for_admin()
returns trigger language plpgsql security definer set search_path to 'public' as $f$
begin
  if NEW.name = 'ADMIN' then
    insert into public.permissions (role_id, module, action, branch_scope, granted)
    select NEW.id, 'accounting', a.action, 'ALL', true
    from (values ('read'),('create'),('update'),('delete'),('approve'),('export')) as a(action)
    on conflict (role_id, module, action) do nothing;
  end if;
  return NEW;
end $f$;
drop trigger if exists trg_seed_accounting_perms on public.roles;
create trigger trg_seed_accounting_perms after insert on public.roles
  for each row execute function public.seed_accounting_perms_for_admin();

-- ========== SEED: default Chart of Accounts for every tenant ==========
-- Stable codes the JournalEngine resolves by. is_system=true (undeletable). Idempotent via WHERE NOT EXISTS.
insert into public.accounts (tenant_id, code, name, type, is_system)
select t.id, v.code, v.name, v.type::account_type_enum, true
from public.tenants t
cross join (values
  ('1000','Cash','ASSET'),
  ('1010','Bank','ASSET'),
  ('1100','Accounts Receivable','ASSET'),
  ('1200','Inventory','ASSET'),
  ('1300','Input Tax (Receivable)','ASSET'),
  ('2000','Accounts Payable','LIABILITY'),
  ('2100','Output Tax (Payable)','LIABILITY'),
  ('3000','Owner Equity','EQUITY'),
  ('3100','Retained Earnings','EQUITY'),
  ('4000','Sales Revenue','REVENUE'),
  ('4100','Sales Returns','REVENUE'),
  ('5000','Cost of Goods Sold','EXPENSE'),
  ('5100','Purchase Returns','EXPENSE'),
  ('6000','Operating Expenses','EXPENSE'),
  ('6100','Rounding Difference','EXPENSE')
) as v(code, name, type)
where not exists (select 1 from public.accounts a where a.tenant_id=t.id and a.code=v.code);

-- ========== SEED: current fiscal period (calendar month) for every tenant ==========
insert into public.fiscal_periods (tenant_id, name, start_date, end_date, status)
select t.id, to_char(current_date,'Mon YYYY'), date_trunc('month', current_date)::date,
       (date_trunc('month', current_date) + interval '1 month - 1 day')::date, 'OPEN'
from public.tenants t
where not exists (
  select 1 from public.fiscal_periods fp
  where fp.tenant_id=t.id and current_date between fp.start_date and fp.end_date);

-- ========== SEED: default tax rule (GST 17% exclusive) per tenant ==========
insert into public.tax_rules (tenant_id, name, code, rate, mode, is_default, applies_to)
select t.id, 'GST 17%', 'GST17', 17.00, 'EXCLUSIVE', true, 'ALL'
from public.tenants t
where not exists (select 1 from public.tax_rules tr where tr.tenant_id=t.id and tr.code='GST17');

-- ========== helper: resolve a system account id by code (used by JournalEngine + auto-post) ==========
create or replace function public.acct_id(p_tenant uuid, p_code varchar)
returns uuid language sql stable security definer set search_path to 'public' as $$
  select id from public.accounts where tenant_id=p_tenant and code=p_code and deleted_at is null limit 1;
$$;

-- ========== helper: find/create the OPEN fiscal period covering a date ==========
create or replace function public.current_fiscal_period(p_tenant uuid, p_date date default current_date)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare v_id uuid;
begin
  select id into v_id from public.fiscal_periods
   where tenant_id=p_tenant and p_date between start_date and end_date and status='OPEN' limit 1;
  if v_id is null then
    insert into public.fiscal_periods (tenant_id, name, start_date, end_date, status)
    values (p_tenant, to_char(p_date,'Mon YYYY'), date_trunc('month',p_date)::date,
            (date_trunc('month',p_date)+interval '1 month - 1 day')::date, 'OPEN')
    returning id into v_id;
  end if;
  return v_id;
end $$;