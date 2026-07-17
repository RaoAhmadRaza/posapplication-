-- Phase 2 — Staff-invite schema. Basis: RUNBOOK v3 §2.
-- 2.0 SKIPPED: uq_user_branch unique index on (user_id, branch_id) already exists (0.1) —
--   ON CONFLICT works off it; a named constraint would be a redundant second unique index.
-- Additive + idempotent. No write policies: definer RPCs only (Phase 3). No anon policy.

-- ===== 2.1  Enum (no CLAIMED state — awaiting-confirmation is computed from
-- auth.users.email_confirmed_at, §3.5) =====
do $$ begin
  create type public.invite_status_enum as enum ('PENDING','REDEEMED','REVOKED','EXPIRED');
exception when duplicate_object then null; end $$;

-- ===== 2.2  Tables =====
create table if not exists public.staff_invites (
  id           uuid primary key default gen_random_uuid(),
  tenant_id    uuid not null references public.tenants(id) on delete cascade,
  role_id      uuid not null references public.roles(id)   on delete restrict,
  employee_id  uuid references public.employees(id) on delete set null,
  token_hash   text not null,
  full_name    text,
  email        text,
  status       public.invite_status_enum not null default 'PENDING',
  expires_at   timestamptz not null,
  max_uses     integer not null default 1 check (max_uses >= 1),
  used_count   integer not null default 0 check (used_count >= 0),
  redeemed_by  uuid references public.users(id) on delete set null,
  redeemed_at  timestamptz,
  revoked_at   timestamptz,
  revoked_by   uuid references public.users(id) on delete set null,
  created_by   uuid not null references public.users(id) on delete restrict,
  created_at   timestamptz not null default now(),
  constraint staff_invites_token_hash_key unique (token_hash),
  constraint staff_invites_uses_ck check (used_count <= max_uses)
);

create table if not exists public.staff_invite_branches (
  invite_id  uuid not null references public.staff_invites(id) on delete cascade,
  branch_id  uuid not null references public.branches(id) on delete cascade,
  is_default boolean not null default false,
  primary key (invite_id, branch_id)
);

create index if not exists staff_invites_tenant_status_idx on public.staff_invites (tenant_id, status);
create index if not exists staff_invites_pending_expiry_idx on public.staff_invites (expires_at) where status = 'PENDING';

-- ===== 2.3  RLS — read-only for tenant admins; all writes via definer RPCs (Phase 3) =====
alter table public.staff_invites enable row level security;
alter table public.staff_invite_branches enable row level security;

drop policy if exists "staff_invites tenant read" on public.staff_invites;
create policy "staff_invites tenant read" on public.staff_invites
for select to authenticated
using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('users','read'));

drop policy if exists "staff_invite_branches tenant read" on public.staff_invite_branches;
create policy "staff_invite_branches tenant read" on public.staff_invite_branches
for select to authenticated
using (exists (select 1 from public.staff_invites si
               where si.id = invite_id and si.tenant_id = public.auth_tenant_id()));
