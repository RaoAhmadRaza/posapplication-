-- ========== HR enums — verbatim §3.10 (schema lines 187–193) ==========
do $$ begin create type public.employee_status_enum as enum ('ACTIVE','ON_LEAVE','SUSPENDED','TERMINATED','RESIGNED'); exception when duplicate_object then null; end $$;
do $$ begin create type public.salary_type_enum as enum ('MONTHLY','DAILY','HOURLY'); exception when duplicate_object then null; end $$;
do $$ begin create type public.attendance_status_enum as enum ('PRESENT','ABSENT','LATE','HALF_DAY','ON_LEAVE','HOLIDAY'); exception when duplicate_object then null; end $$;
do $$ begin create type public.leave_type_enum as enum ('ANNUAL','SICK','UNPAID','MATERNITY','PATERNITY','CASUAL'); exception when duplicate_object then null; end $$;
do $$ begin create type public.leave_status_enum as enum ('PENDING','APPROVED','REJECTED','CANCELLED'); exception when duplicate_object then null; end $$;
do $$ begin create type public.payroll_status_enum as enum ('DRAFT','CALCULATED','APPROVED','DISBURSED','CANCELLED'); exception when duplicate_object then null; end $$;
do $$ begin create type public.payroll_item_status_enum as enum ('PENDING','PAID','HELD','CANCELLED'); exception when duplicate_object then null; end $$;

-- ========== employees — verbatim §3.10 ==========
create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid not null references public.branches(id),
  user_id uuid references public.users(id),
  employee_code varchar(50) not null,
  name varchar(255) not null,
  cnic varchar(20),
  phone varchar(50),
  email varchar(255),
  address text,
  designation varchar(100),
  department varchar(100),
  joining_date date not null,
  termination_date date,
  salary_type salary_type_enum not null default 'MONTHLY',
  base_salary decimal(15,4) not null default 0,
  bank_name varchar(255),
  bank_account_number varchar(100),
  emergency_contact varchar(255),
  emergency_phone varchar(50),
  documents_json jsonb default '[]'::jsonb,
  status employee_status_enum not null default 'ACTIVE',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  version integer not null default 1,
  created_by uuid references public.users(id),
  updated_by uuid references public.users(id)
);
create unique index if not exists uq_employees_tenant_code on public.employees(tenant_id, employee_code) where deleted_at is null;
create index if not exists idx_employees_branch on public.employees(branch_id) where deleted_at is null;
create index if not exists idx_employees_user on public.employees(user_id) where user_id is not null and deleted_at is null;
create index if not exists idx_employees_status on public.employees(tenant_id, status) where deleted_at is null;
create index if not exists idx_employees_department on public.employees(tenant_id, department) where deleted_at is null;

-- ========== shifts — verbatim §3.10 ==========
create table if not exists public.shifts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name varchar(100) not null,
  start_time time not null,
  end_time time not null,
  grace_minutes integer not null default 15,
  break_minutes integer not null default 60,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index if not exists uq_shifts_tenant_name on public.shifts(tenant_id, name) where deleted_at is null;

-- ========== RLS: tenant read; hr-gated writes ==========
alter table public.employees enable row level security;
drop policy if exists "emp tenant read" on public.employees;
create policy "emp tenant read" on public.employees for select to authenticated using (tenant_id = public.auth_tenant_id());
drop policy if exists "emp gated write" on public.employees;
create policy "emp gated write" on public.employees for all to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('hr','update'))
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('hr','update'));

alter table public.shifts enable row level security;
drop policy if exists "shift tenant read" on public.shifts;
create policy "shift tenant read" on public.shifts for select to authenticated using (tenant_id = public.auth_tenant_id());
drop policy if exists "shift gated write" on public.shifts;
create policy "shift gated write" on public.shifts for all to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('hr','update'))
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('hr','update'));

-- ========== PERMISSION MODULE: hr (mirror 'repair' backfill + roles trigger) ==========
insert into public.permissions (role_id, module, action, branch_scope, granted)
select r.id, 'hr', a.action, 'ALL', true
from public.roles r cross join (values ('read'),('create'),('update'),('delete'),('approve'),('export')) as a(action)
where r.name='ADMIN' on conflict (role_id, module, action) do nothing;

create or replace function public.seed_hr_perms_for_admin()
returns trigger language plpgsql security definer set search_path to 'public' as $f$
begin
  if NEW.name='ADMIN' then
    insert into public.permissions (role_id, module, action, branch_scope, granted)
    select NEW.id, 'hr', a.action, 'ALL', true
    from (values ('read'),('create'),('update'),('delete'),('approve'),('export')) as a(action)
    on conflict (role_id, module, action) do nothing;
  end if; return NEW;
end $f$;
drop trigger if exists trg_seed_hr_perms on public.roles;
create trigger trg_seed_hr_perms after insert on public.roles for each row execute function public.seed_hr_perms_for_admin();

-- ========== CoA seeds (existing tenants) — idempotent. CODES SIGNED OFF IN H0. ==========
-- 5200 is Warranty Cost (repair) — DO NOT reuse. These are new, free codes.
insert into public.accounts (tenant_id, code, name, type, is_system)
select t.id, v.code, v.name, v.type::account_type_enum, true
from public.tenants t
cross join (values
  ('6200','Salary Expense','EXPENSE'),
  ('2120','Payroll Deductions Payable','LIABILITY'),
  ('1150','Employee Advances','ASSET')
) as v(code,name,type)
where not exists (select 1 from public.accounts a where a.tenant_id=t.id and a.code=v.code and a.deleted_at is null);