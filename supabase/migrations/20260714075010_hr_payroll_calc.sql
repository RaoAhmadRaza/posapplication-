-- ========== payroll_runs / payroll_items / salary_advances — verbatim §3.10 ==========
create table if not exists public.payroll_runs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid references public.branches(id),
  period varchar(20) not null,
  period_start date not null,
  period_end date not null,
  status payroll_status_enum not null default 'DRAFT',
  total_gross decimal(15,4) not null default 0,
  total_deductions decimal(15,4) not null default 0,
  total_net decimal(15,4) not null default 0,
  employee_count integer not null default 0,
  run_by uuid not null references public.users(id),
  approved_by uuid references public.users(id),
  approved_at timestamptz,
  disbursed_at timestamptz,
  journal_entry_id uuid references public.journal_entries(id),
  correlation_id uuid,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1
);
create unique index if not exists uq_payroll_runs_period on public.payroll_runs(tenant_id, branch_id, period);
create index if not exists idx_payroll_runs_status on public.payroll_runs(tenant_id, status);

create table if not exists public.payroll_items (
  id uuid primary key default gen_random_uuid(),
  run_id uuid not null references public.payroll_runs(id) on delete cascade,
  employee_id uuid not null references public.employees(id),
  basic decimal(15,4) not null,
  allowances_json jsonb not null default '{}'::jsonb,
  deductions_json jsonb not null default '{}'::jsonb,
  overtime_hours decimal(5,2) not null default 0,
  overtime_amount decimal(15,4) not null default 0,
  gross_salary decimal(15,4) not null,
  total_deductions decimal(15,4) not null,
  net_salary decimal(15,4) not null,
  status payroll_item_status_enum not null default 'PENDING',
  payment_reference varchar(255),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists uq_payroll_items_run_employee on public.payroll_items(run_id, employee_id);
create index if not exists idx_payroll_items_employee on public.payroll_items(employee_id);
do $$ begin alter table public.payroll_items add constraint chk_payroll_items_net check (net_salary >= 0); exception when duplicate_object then null; end $$;

create table if not exists public.salary_advances (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  employee_id uuid not null references public.employees(id),
  amount decimal(15,4) not null,
  balance decimal(15,4) not null,
  recovery_amount decimal(15,4) not null,
  recovery_schedule_json jsonb,
  disbursed_at timestamptz not null,
  disbursed_by uuid not null references public.users(id),
  fully_recovered_at timestamptz,
  journal_entry_id uuid references public.journal_entries(id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1
);
create index if not exists idx_salary_advances_employee on public.salary_advances(employee_id);
create index if not exists idx_salary_advances_active on public.salary_advances(tenant_id) where balance > 0;
do $$ begin alter table public.salary_advances add constraint chk_salary_advances_amount check (amount > 0); exception when duplicate_object then null; end $$;
do $$ begin alter table public.salary_advances add constraint chk_salary_advances_balance check (balance >= 0 and balance <= amount); exception when duplicate_object then null; end $$;

-- RLS: tenant read; RPC-only writes on all three
alter table public.payroll_runs enable row level security;
drop policy if exists "pr read" on public.payroll_runs;
create policy "pr read" on public.payroll_runs for select to authenticated using (tenant_id=public.auth_tenant_id());
revoke insert,update,delete on public.payroll_runs from authenticated;
alter table public.payroll_items enable row level security;
drop policy if exists "pi read" on public.payroll_items;
create policy "pi read" on public.payroll_items for select to authenticated using (
  exists (select 1 from payroll_runs r where r.id=run_id and r.tenant_id=public.auth_tenant_id()));
revoke insert,update,delete on public.payroll_items from authenticated;
alter table public.salary_advances enable row level security;
drop policy if exists "sa read" on public.salary_advances;
create policy "sa read" on public.salary_advances for select to authenticated using (tenant_id=public.auth_tenant_id());
revoke insert,update,delete on public.salary_advances from authenticated;

-- create_payroll_run: opens a DRAFT for a period. Unique per (tenant,branch,period).
create or replace function public.create_payroll_run(p_branch_id uuid, p_period varchar, p_start date, p_end date, p_notes text)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid(); v_id uuid;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('hr','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if exists (select 1 from payroll_runs where tenant_id=v_t and coalesce(branch_id,'00000000-0000-0000-0000-000000000000')=coalesce(p_branch_id,'00000000-0000-0000-0000-000000000000') and period=p_period) then raise exception 'ERR_PERIOD_EXISTS'; end if;
  insert into payroll_runs (tenant_id, branch_id, period, period_start, period_end, status, run_by, correlation_id, notes)
  values (v_t, p_branch_id, p_period, p_start, p_end, 'DRAFT', v_uid, gen_random_uuid(), p_notes)
  returning id into v_id;
  return jsonb_build_object('run_id', v_id, 'period', p_period, 'status', 'DRAFT');
end; $function$;

-- calculate_payroll: DRAFT→CALCULATED. Builds one payroll_item per ACTIVE employee in scope.
-- basic (period), + allowances (from p_allowances jsonb per employee, optional), + overtime (from attendance),
-- - deductions. Deduction key 'advance' = auto-recovery from active salary_advances (min(recovery_amount, balance)).
-- deductions_json = { 'advance': X, ...p_extra_deductions } ; net = gross - total_deductions (>=0).
create or replace function public.calculate_payroll(p_run_id uuid, p_allowances jsonb, p_extra_deductions jsonb)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid:=public.auth_tenant_id(); v_run payroll_runs%rowtype; v_emp record;
  v_basic numeric; v_allow numeric; v_ot_hours numeric; v_ot_amt numeric; v_adv numeric; v_extra numeric;
  v_ded numeric; v_gross numeric; v_net numeric; v_dedjson jsonb; v_alljson jsonb;
  v_tg numeric:=0; v_td numeric:=0; v_tn numeric:=0; v_cnt int:=0;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('hr','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select * into v_run from payroll_runs where id=p_run_id and tenant_id=v_t;
  if not found then raise exception 'ERR_RUN_NOT_FOUND'; end if;
  if v_run.status <> 'DRAFT' then raise exception 'ERR_RUN_NOT_DRAFT'; end if;
  delete from payroll_items where run_id=p_run_id;   -- recalc from clean

  for v_emp in select * from employees where tenant_id=v_t and status='ACTIVE' and deleted_at is null
      and (v_run.branch_id is null or branch_id=v_run.branch_id) loop
    v_basic := coalesce(v_emp.base_salary,0);   -- MONTHLY: full period basic (pro-ration deferred — see Deferred)
    v_alljson := coalesce(p_allowances->(v_emp.id::text), '{}'::jsonb);
    select coalesce(sum((value)::numeric),0) into v_allow from jsonb_each_text(v_alljson);
    select coalesce(sum(overtime_hours),0) into v_ot_hours from attendance
      where employee_id=v_emp.id and date between v_run.period_start and v_run.period_end;
    v_ot_amt := round(v_ot_hours * (v_basic/30.0/8.0), 4);   -- simple OT rate = hourly basic; refine per policy
    -- advance auto-recovery
    select coalesce(sum(least(recovery_amount, balance)),0) into v_adv from salary_advances
      where tenant_id=v_t and employee_id=v_emp.id and balance > 0;
    v_extra := 0;
    if p_extra_deductions ? (v_emp.id::text) then
      select coalesce(sum((value)::numeric),0) into v_extra from jsonb_each_text(p_extra_deductions->(v_emp.id::text));
    end if;
    v_dedjson := jsonb_build_object('advance', v_adv) || coalesce(p_extra_deductions->(v_emp.id::text), '{}'::jsonb);
    v_gross := round(v_basic + v_allow + v_ot_amt, 4);
    v_ded   := round(v_adv + v_extra, 4);
    v_net   := round(v_gross - v_ded, 4);
    if v_net < 0 then raise exception 'ERR_NEGATIVE_NET for employee %', v_emp.employee_code; end if;
    insert into payroll_items (run_id, employee_id, basic, allowances_json, deductions_json, overtime_hours,
      overtime_amount, gross_salary, total_deductions, net_salary, status)
    values (p_run_id, v_emp.id, v_basic, v_alljson, v_dedjson, v_ot_hours, v_ot_amt, v_gross, v_ded, v_net, 'PENDING');
    v_tg:=v_tg+v_gross; v_td:=v_td+v_ded; v_tn:=v_tn+v_net; v_cnt:=v_cnt+1;
  end loop;

  update payroll_runs set status='CALCULATED', total_gross=v_tg, total_deductions=v_td, total_net=v_tn,
    employee_count=v_cnt, updated_at=now(), version=version+1 where id=p_run_id;
  return jsonb_build_object('run_id', p_run_id, 'employees', v_cnt, 'total_gross', v_tg, 'total_net', v_tn);
end; $function$;

-- approve_payroll_run: CALCULATED→APPROVED. Gated hr:approve (manager). No GL yet.
create or replace function public.approve_payroll_run(p_run_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid(); v_st payroll_status_enum;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('hr','approve') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select status into v_st from payroll_runs where id=p_run_id and tenant_id=v_t;
  if not found then raise exception 'ERR_RUN_NOT_FOUND'; end if;
  if v_st <> 'CALCULATED' then raise exception 'ERR_RUN_NOT_CALCULATED'; end if;
  update payroll_runs set status='APPROVED', approved_by=v_uid, approved_at=now(), updated_at=now(), version=version+1 where id=p_run_id;
  return jsonb_build_object('run_id', p_run_id, 'status', 'APPROVED');
end; $function$;