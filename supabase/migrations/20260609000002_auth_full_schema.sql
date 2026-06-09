-- 20260609000002_auth_full_schema.sql
-- Phase 0.2 — Full auth schema: RBAC, branches, devices, sessions, MFA, audit logs,
-- RLS helpers, default permission matrix, and full-provisioning signup trigger.
-- Additive + idempotent + ordered. Applies on top of:
--   20260609000000_init.sql
--   20260609000001_signup_provisioning.sql
-- Supabase Auth (auth.users) owns credentials/sessions/JWT. public.users is a profile.
-- NO password is ever stored in public.users.

-- ===== Enums (guarded) =====
do $$ begin create type user_status_enum as enum ('ACTIVE','INACTIVE','SUSPENDED','LOCKED'); exception when duplicate_object then null; end $$;
do $$ begin create type device_trust_level_enum as enum ('PENDING','TRUSTED','RESTRICTED','SUSPICIOUS','REVOKED','EXPIRED'); exception when duplicate_object then null; end $$;
do $$ begin create type session_status_enum as enum ('ACTIVE','EXPIRED','REVOKED'); exception when duplicate_object then null; end $$;
do $$ begin create type branch_scope_enum as enum ('ALL','OWN_BRANCH','ASSIGNED_BRANCHES'); exception when duplicate_object then null; end $$;

-- ===== Extend existing tables (additive; keeps app working) =====
alter table public.tenants  add column if not exists slug text;
alter table public.tenants  add column if not exists settings_json jsonb not null default '{}'::jsonb;
alter table public.tenants  add column if not exists is_active boolean not null default true;

alter table public.roles    add column if not exists description text;
alter table public.roles    add column if not exists is_system_role boolean not null default false;
alter table public.roles    add column if not exists hierarchy_level integer not null default 99;
alter table public.roles    add column if not exists requires_mfa boolean not null default false;

alter table public.users    add column if not exists phone text;
alter table public.users    add column if not exists avatar_url text;
alter table public.users    add column if not exists last_login_at timestamptz;
alter table public.users    add column if not exists failed_login_count integer not null default 0;
alter table public.users    add column if not exists locked_until timestamptz;
alter table public.users    add column if not exists pin_hash text;          -- quick-login PIN (hashed)
-- NOTE: no password_hash column — Supabase owns the password in auth.users.

-- ===== Branches =====
create table if not exists public.branches (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name text not null,
  code text not null,
  city text, country text default 'Pakistan',
  currency text not null default 'PKR',
  timezone text not null default 'Asia/Karachi',
  is_active boolean not null default true,
  is_main boolean not null default false,
  created_at timestamptz not null default now()
);
create unique index if not exists uq_branches_tenant_code on public.branches(tenant_id, code);
create index if not exists idx_branches_tenant on public.branches(tenant_id);

-- ===== User <-> Branch assignments =====
create table if not exists public.user_branch_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  branch_id uuid not null references public.branches(id) on delete cascade,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);
create unique index if not exists uq_user_branch on public.user_branch_assignments(user_id, branch_id);

-- ===== RBAC permissions =====
create table if not exists public.permissions (
  id uuid primary key default gen_random_uuid(),
  role_id uuid not null references public.roles(id) on delete cascade,
  module text not null,
  action text not null,
  branch_scope branch_scope_enum not null default 'OWN_BRANCH',
  granted boolean not null default false,
  created_at timestamptz not null default now()
);
create unique index if not exists uq_permissions_role_module_action on public.permissions(role_id, module, action);
create index if not exists idx_permissions_role on public.permissions(role_id);

-- ===== Devices =====
create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  user_id uuid references public.users(id),
  branch_id uuid references public.branches(id),
  device_name text not null,
  device_model text,
  os_info text,
  fingerprint_hash text not null,
  trust_level device_trust_level_enum not null default 'PENDING',
  authorized boolean not null default false,
  last_seen_at timestamptz,
  authorized_at timestamptz,
  authorized_by uuid references public.users(id),
  created_at timestamptz not null default now()
);
create unique index if not exists uq_devices_fingerprint on public.devices(fingerprint_hash);
create index if not exists idx_devices_tenant on public.devices(tenant_id);
create index if not exists idx_devices_user on public.devices(user_id);

-- ===== App-level session records (Supabase manages REAL sessions; this is for device/audit tracking) =====
create table if not exists public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id),
  device_id uuid references public.devices(id),
  branch_id uuid references public.branches(id),
  ip_address inet,
  user_agent text,
  status session_status_enum not null default 'ACTIVE',
  expires_at timestamptz,
  revoked_at timestamptz,
  revoked_reason text,
  created_at timestamptz not null default now()
);
create index if not exists idx_sessions_user on public.sessions(user_id, status);

-- ===== MFA config (Supabase stores the real TOTP factor in auth schema; this tracks app-level flags) =====
create table if not exists public.mfa_configs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) unique,
  enabled boolean not null default false,
  sms_phone text,
  last_used_at timestamptz,
  created_at timestamptz not null default now()
);

-- ===== Audit logs (IMMUTABLE) =====
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id),
  user_id uuid references public.users(id),
  device_id uuid references public.devices(id),
  action text not null,
  entity text not null,
  entity_id uuid,
  old_values jsonb,
  new_values jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_audit_user on public.audit_logs(user_id, created_at);

-- ===== RLS helpers (Supabase translation of the schema doc's SET LOCAL tenant isolation) =====
create or replace function public.auth_tenant_id()
returns uuid language sql stable security definer set search_path = public as $$
  select tenant_id from public.users where id = auth.uid();
$$;
create or replace function public.auth_role_name()
returns text language sql stable security definer set search_path = public as $$
  select r.name from public.users u join public.roles r on r.id = u.role_id where u.id = auth.uid();
$$;

-- ===== RLS on new tables (tenant-isolated; admin-only writes where sensitive) =====
alter table public.branches enable row level security;
drop policy if exists "branches tenant read" on public.branches;
create policy "branches tenant read" on public.branches for select to authenticated using (tenant_id = public.auth_tenant_id());
drop policy if exists "branches admin write" on public.branches;
create policy "branches admin write" on public.branches for all to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_role_name() = 'ADMIN')
  with check (tenant_id = public.auth_tenant_id() and public.auth_role_name() = 'ADMIN');

alter table public.user_branch_assignments enable row level security;
drop policy if exists "uba self read" on public.user_branch_assignments;
create policy "uba self read" on public.user_branch_assignments for select to authenticated using (user_id = auth.uid());

alter table public.permissions enable row level security;
drop policy if exists "perm tenant read" on public.permissions;
create policy "perm tenant read" on public.permissions for select to authenticated
  using (exists (select 1 from public.roles r where r.id = permissions.role_id and r.tenant_id = public.auth_tenant_id()));

alter table public.devices enable row level security;
drop policy if exists "devices tenant read" on public.devices;
create policy "devices tenant read" on public.devices for select to authenticated using (tenant_id = public.auth_tenant_id());
drop policy if exists "devices self insert" on public.devices;
create policy "devices self insert" on public.devices for insert to authenticated with check (tenant_id = public.auth_tenant_id());
drop policy if exists "devices admin manage" on public.devices;
create policy "devices admin manage" on public.devices for update to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_role_name() = 'ADMIN');

alter table public.sessions enable row level security;
drop policy if exists "sessions self" on public.sessions;
create policy "sessions self" on public.sessions for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.mfa_configs enable row level security;
drop policy if exists "mfa self" on public.mfa_configs;
create policy "mfa self" on public.mfa_configs for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

alter table public.audit_logs enable row level security;
drop policy if exists "audit tenant read" on public.audit_logs;
create policy "audit tenant read" on public.audit_logs for select to authenticated using (tenant_id = public.auth_tenant_id());
drop policy if exists "audit self insert" on public.audit_logs;
create policy "audit self insert" on public.audit_logs for insert to authenticated with check (user_id = auth.uid());
-- Immutability: no update/delete grants for clients.
revoke update, delete on public.audit_logs from anon, authenticated;

-- ===== Seed default permission matrix for the existing Demo Store roles =====
-- ADMIN (Demo Store) — full matrix
insert into public.permissions (role_id, module, action, branch_scope, granted)
select '00000000-0000-0000-0000-000000000011', m, a, 'ALL', true
from unnest(array['sales','inventory','customers','reports','settings','users']) m
cross join unnest(array['read','create','update','delete','approve','export']) a
on conflict (role_id, module, action) do nothing;

-- CASHIER (Demo Store) — limited matrix
insert into public.permissions (role_id, module, action, branch_scope, granted) values
  ('00000000-0000-0000-0000-000000000012','sales','read','OWN_BRANCH',true),
  ('00000000-0000-0000-0000-000000000012','sales','create','OWN_BRANCH',true),
  ('00000000-0000-0000-0000-000000000012','inventory','read','OWN_BRANCH',true),
  ('00000000-0000-0000-0000-000000000012','customers','read','OWN_BRANCH',true),
  ('00000000-0000-0000-0000-000000000012','customers','create','OWN_BRANCH',true),
  ('00000000-0000-0000-0000-000000000012','reports','read','OWN_BRANCH',true)
on conflict (role_id, module, action) do nothing;

-- A default main branch for the Demo Store + assign existing users to it
insert into public.branches (id, tenant_id, name, code, is_main)
values ('00000000-0000-0000-0000-0000000000b1','00000000-0000-0000-0000-000000000001','Main Branch','BR01',true)
on conflict (id) do nothing;
insert into public.user_branch_assignments (user_id, branch_id, is_default)
select u.id, '00000000-0000-0000-0000-0000000000b1', true from public.users u
where u.tenant_id = '00000000-0000-0000-0000-000000000001'
on conflict (user_id, branch_id) do nothing;

-- ===== Upgrade signup trigger: full provisioning for a new tenant =====
-- FIX vs runbook: the fallback (no business_name) branch assigns Demo Store CASHIER (…012),
-- NOT Demo Store ADMIN (…011), per the locked provisioning rule
-- (business_name -> own tenant as ADMIN; else Demo Store / CASHIER).
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_business_name   text := nullif(trim(new.raw_user_meta_data->>'business_name'), '');
  v_full_name       text := coalesce(new.raw_user_meta_data->>'full_name', '');
  v_tenant_id       uuid;
  v_role_id         uuid;   -- role assigned to the new user (ADMIN for business owner, CASHIER for fallback)
  v_cashier_role_id uuid;
  v_branch_id       uuid;
begin
  if v_business_name is not null then
    insert into public.tenants (name) values (v_business_name) returning id into v_tenant_id;

    insert into public.roles (tenant_id, name, is_system_role, hierarchy_level)
      values (v_tenant_id,'ADMIN',true,1) returning id into v_role_id;          -- business owner = ADMIN
    insert into public.roles (tenant_id, name, is_system_role, hierarchy_level)
      values (v_tenant_id,'CASHIER',true,5) returning id into v_cashier_role_id;

    insert into public.branches (tenant_id, name, code, is_main)
      values (v_tenant_id,'Main Branch','BR01',true) returning id into v_branch_id;

    -- ADMIN: full matrix
    insert into public.permissions (role_id, module, action, branch_scope, granted)
    select v_role_id, m, a, 'ALL', true
    from unnest(array['sales','inventory','customers','reports','settings','users']) m
    cross join unnest(array['read','create','update','delete','approve','export']) a;

    -- CASHIER: limited matrix
    insert into public.permissions (role_id, module, action, branch_scope, granted) values
      (v_cashier_role_id,'sales','read','OWN_BRANCH',true),
      (v_cashier_role_id,'sales','create','OWN_BRANCH',true),
      (v_cashier_role_id,'inventory','read','OWN_BRANCH',true),
      (v_cashier_role_id,'customers','read','OWN_BRANCH',true),
      (v_cashier_role_id,'customers','create','OWN_BRANCH',true),
      (v_cashier_role_id,'reports','read','OWN_BRANCH',true);
  else
    v_tenant_id := '00000000-0000-0000-0000-000000000001';   -- Demo Store
    v_role_id   := '00000000-0000-0000-0000-000000000012';   -- Demo Store CASHIER (fallback)
    v_branch_id := '00000000-0000-0000-0000-0000000000b1';   -- Demo Store Main Branch
  end if;

  insert into public.users (id, tenant_id, role_id, email, full_name)
    values (new.id, v_tenant_id, v_role_id, new.email, v_full_name)
    on conflict (id) do nothing;

  insert into public.user_branch_assignments (user_id, branch_id, is_default)
    values (new.id, v_branch_id, true) on conflict (user_id, branch_id) do nothing;

  return new;
end;
$$;