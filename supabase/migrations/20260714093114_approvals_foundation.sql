-- ========== enums — verbatim §2 (schema lines 204–205). Guarded (may already exist per A0.2). ==========
do $$ begin create type public.approval_status_enum as enum ('PENDING','APPROVED','REJECTED','ESCALATED','EXPIRED','CANCELLED'); exception when duplicate_object then null; end $$;
do $$ begin create type public.approval_workflow_type_enum as enum ('PURCHASE_ORDER','STOCK_ADJUSTMENT','DISCOUNT_OVERRIDE','PAYROLL_DISBURSEMENT','CREDIT_LIMIT_CHANGE','PRICE_CHANGE','REFUND','EXPENSE'); exception when duplicate_object then null; end $$;

-- ========== approval_workflows — verbatim §3.17 ==========
create table if not exists public.approval_workflows (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  workflow_type approval_workflow_type_enum not null,
  name varchar(255) not null,
  description text,
  threshold_amount decimal(15,4),
  levels_json jsonb not null,
  escalation_ttl_hours integer not null default 24,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  version integer not null default 1
);
create index if not exists idx_approval_workflows_tenant on public.approval_workflows(tenant_id, workflow_type) where deleted_at is null;
create index if not exists idx_approval_workflows_active on public.approval_workflows(tenant_id) where is_active = true and deleted_at is null;

-- ========== approval_requests — verbatim §3.17 ==========
create table if not exists public.approval_requests (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  workflow_id uuid not null references public.approval_workflows(id),
  entity_type varchar(50) not null,
  entity_id uuid not null,
  requestor_id uuid not null references public.users(id),
  status approval_status_enum not null default 'PENDING',
  current_level integer not null default 1,
  amount decimal(15,4),
  reason text,
  expires_at timestamptz,
  escalated_at timestamptz,
  completed_at timestamptz,
  correlation_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1
);
create index if not exists idx_approval_requests_tenant_status on public.approval_requests(tenant_id, status);
create index if not exists idx_approval_requests_entity on public.approval_requests(entity_type, entity_id);
create index if not exists idx_approval_requests_requestor on public.approval_requests(requestor_id);
create index if not exists idx_approval_requests_pending on public.approval_requests(tenant_id) where status in ('PENDING','ESCALATED');
create index if not exists idx_approval_requests_expires on public.approval_requests(expires_at) where status='PENDING' and expires_at is not null;
-- one OPEN request per entity (prevents duplicate PENDING/ESCALATED for the same thing)
create unique index if not exists uq_approval_requests_open_entity on public.approval_requests(entity_type, entity_id) where status in ('PENDING','ESCALATED');

-- ========== approval_actions — verbatim §3.17 (append-only audit) ==========
create table if not exists public.approval_actions (
  id uuid primary key default gen_random_uuid(),
  request_id uuid not null references public.approval_requests(id) on delete cascade,
  actor_id uuid not null references public.users(id),
  action varchar(20) not null,
  level integer not null,
  comments text,
  acted_at timestamptz not null default now()
);
create index if not exists idx_approval_actions_request on public.approval_actions(request_id, acted_at);
create index if not exists idx_approval_actions_actor on public.approval_actions(actor_id);

-- ========== RLS: tenant read; RPC-only writes (engine RPCs are SECURITY DEFINER) ==========
alter table public.approval_workflows enable row level security;
drop policy if exists "aw tenant read" on public.approval_workflows;
create policy "aw tenant read" on public.approval_workflows for select to authenticated using (tenant_id=public.auth_tenant_id());
drop policy if exists "aw gated write" on public.approval_workflows;
create policy "aw gated write" on public.approval_workflows for all to authenticated
  using (tenant_id=public.auth_tenant_id() and public.auth_has_permission('approvals','update'))
  with check (tenant_id=public.auth_tenant_id() and public.auth_has_permission('approvals','update'));

alter table public.approval_requests enable row level security;
drop policy if exists "ar tenant read" on public.approval_requests;
create policy "ar tenant read" on public.approval_requests for select to authenticated using (tenant_id=public.auth_tenant_id());
revoke insert,update,delete on public.approval_requests from authenticated;   -- via engine RPCs only

alter table public.approval_actions enable row level security;
drop policy if exists "aa tenant read" on public.approval_actions;
create policy "aa tenant read" on public.approval_actions for select to authenticated using (
  exists (select 1 from public.approval_requests r where r.id=request_id and r.tenant_id=public.auth_tenant_id()));
revoke insert,update,delete on public.approval_actions from authenticated;

-- ========== PERMISSION MODULE: approvals (mirror repair/hr backfill + roles trigger) ==========
insert into public.permissions (role_id, module, action, branch_scope, granted)
select r.id, 'approvals', a.action, 'ALL', true
from public.roles r cross join (values ('read'),('create'),('update'),('delete'),('approve'),('export')) as a(action)
where r.name='ADMIN' on conflict (role_id, module, action) do nothing;

create or replace function public.seed_approvals_perms_for_admin()
returns trigger language plpgsql security definer set search_path to 'public' as $f$
begin
  if NEW.name='ADMIN' then
    insert into public.permissions (role_id, module, action, branch_scope, granted)
    select NEW.id, 'approvals', a.action, 'ALL', true
    from (values ('read'),('create'),('update'),('delete'),('approve'),('export')) as a(action)
    on conflict (role_id, module, action) do nothing;
  end if; return NEW;
end $f$;
drop trigger if exists trg_seed_approvals_perms on public.roles;
create trigger trg_seed_approvals_perms after insert on public.roles for each row execute function public.seed_approvals_perms_for_admin();