create type sync_intent_status_enum    as enum ('PENDING','REPLAYING','APPLIED','FAILED','ABANDONED');
create type sync_exception_status_enum as enum ('OPEN','RESOLVED','WRITTEN_OFF');

create table if not exists public.sync_outbox (
  id                uuid primary key default gen_random_uuid(),
  tenant_id         uuid not null references tenants(id)  on delete restrict,
  branch_id         uuid not null references branches(id) on delete restrict,
  device_id         uuid          references devices(id)  on delete set null,
  user_id           uuid not null references users(id)    on delete restrict,
  idempotency_key   uuid not null,                       -- client-generated (uuid v4), the whole contract
  intent_type       text not null,
  payload_json      jsonb not null,                      -- the create_sale args, verbatim
  client_created_at timestamptz not null,                -- when the cashier ACTUALLY rang it. See D6/[SIGN-OFF #5].
  local_ref         text,                                -- provisional receipt ref [SIGN-OFF #1(a)]
  status            sync_intent_status_enum not null default 'PENDING',
  attempts          integer not null default 0,
  last_error        text,
  invoice_id        uuid references invoices(id) on delete set null,   -- stamped on APPLIED
  applied_at        timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  constraint uq_sync_outbox_idem unique (tenant_id, idempotency_key),
  constraint ck_sync_outbox_type check (intent_type in ('SALE'))       -- Class B is SALE-only in v1, by construction
);
create index if not exists idx_sync_outbox_drain  on public.sync_outbox(tenant_id, status) where status in ('PENDING','FAILED');
create index if not exists idx_sync_outbox_device on public.sync_outbox(device_id, created_at);

create table if not exists public.sync_exceptions (
  id              uuid primary key default gen_random_uuid(),
  tenant_id       uuid not null references tenants(id)     on delete restrict,
  outbox_id       uuid not null references sync_outbox(id) on delete restrict,
  error_code      text not null,                          -- the VERBATIM ERR_* from create_sale
  error_detail    text,
  payload_json    jsonb not null,                         -- frozen copy of the intent
  status          sync_exception_status_enum not null default 'OPEN',
  resolution_note text,
  resolved_by     uuid references users(id) on delete set null,
  resolved_at     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index if not exists idx_sync_exceptions_open on public.sync_exceptions(tenant_id, status) where status='OPEN';

alter table public.sync_outbox     enable row level security;
alter table public.sync_exceptions enable row level security;
create policy sync_outbox_tenant_read     on public.sync_outbox     for select to authenticated using (tenant_id = public.auth_tenant_id());
create policy sync_exceptions_tenant_read on public.sync_exceptions for select to authenticated using (tenant_id = public.auth_tenant_id());
-- NO insert/update/delete policy: definer RPCs are the ONLY writers, by construction (approvals foundation pattern).

-- NEW 'sync' perm module (+ backfill to ADMIN + trigger), mirroring hr/approvals/notifications.
-- ⚠️ This makes SEVEN seed_*_perms_for_admin triggers on roles. PROJECT_STATE already names the
--    fragmentation as cleanup. Adding the 7th for consistency rather than inventing a special case.
-- backfill existing ADMIN roles across all tenants (mirror of the approvals/hr/repair backfill)
insert into public.permissions (role_id, module, action, branch_scope, granted)
select r.id, 'sync', a.action, 'ALL', true
from public.roles r cross join (values ('read'),('resolve')) as a(action)
where r.name='ADMIN' on conflict (role_id, module, action) do nothing;

create or replace function public.seed_sync_perms_for_admin()
returns trigger language plpgsql security definer set search_path to 'public' as $f$
begin
  if NEW.name='ADMIN' then
    insert into public.permissions (role_id, module, action, branch_scope, granted)
    select NEW.id, 'sync', a.action, 'ALL', true
    from (values ('read'),('resolve')) as a(action)
    on conflict (role_id, module, action) do nothing;
  end if; return NEW;
end $f$;
drop trigger if exists trg_seed_sync_perms on public.roles;
create trigger trg_seed_sync_perms after insert on public.roles for each row execute function public.seed_sync_perms_for_admin();