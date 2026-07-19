-- Cluster I (sessions half): public.sessions was created and READ (list-sessions
-- Edge Function) but NOTHING ever wrote to it — zero INSERTs in any migration, no
-- trigger, no client path — so /sessions was always empty (SESSIONS-001/002/003).
--
-- Two mismatches had to be reconciled: the list-sessions Edge Function selects
-- `last_active_at` and filters `.eq("tenant_id", ...)`, but the table (created in
-- 20260609000002_auth_full_schema.sql:95-108) has NEITHER column — so the read path
-- would 500 even once rows existed. Both columns are added here.
--
-- Write mechanism = Option A (DB trigger mirroring auth.sessions), the source of
-- truth for real sessions. Every login inserts an auth.sessions row; sign-out
-- deletes it; token refresh updates refreshed_at. Mirroring it means /sessions
-- reflects actual sessions across devices with the client staying dumb, and
-- sign-out flips the mirror to REVOKED automatically. Precedent: handle_new_user
-- already triggers on auth.users, so triggers on auth.* are supported here.

-- 1) Additive columns the read path already assumes.
alter table public.sessions
  add column if not exists tenant_id uuid references public.tenants(id);
alter table public.sessions
  add column if not exists last_active_at timestamptz;

create index if not exists idx_sessions_tenant on public.sessions(tenant_id, status);

-- 2) Mirror function: keep public.sessions in sync with auth.sessions. SECURITY
--    DEFINER (owned by postgres) so it can write public.sessions and read
--    public.users regardless of RLS, and run inside GoTrue's insert context.
create or replace function public.sync_session_from_auth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id uuid;
begin
  -- This trigger fires INSIDE GoTrue's login/refresh/logout transaction. A mirror
  -- failure must never break authentication, so the whole body is guarded: on any
  -- error we warn and let the auth operation proceed. /sessions being briefly out
  -- of sync is strictly preferable to a login outage.
  begin
    if tg_op = 'DELETE' then
      -- Sign-out / global revoke deletes the auth.sessions row.
      update public.sessions
         set status = 'REVOKED', revoked_at = now()
       where id = old.id and status <> 'REVOKED';
      return old;
    end if;

    select tenant_id into v_tenant_id from public.users where id = new.user_id;

    insert into public.sessions (
      id, user_id, tenant_id, ip_address, user_agent,
      status, expires_at, created_at, last_active_at
    ) values (
      new.id, new.user_id, v_tenant_id, new.ip, new.user_agent,
      'ACTIVE', new.not_after, coalesce(new.created_at, now()),
      coalesce(new.refreshed_at, new.updated_at, new.created_at, now())
    )
    on conflict (id) do update set
      last_active_at = coalesce(new.refreshed_at, new.updated_at, now()),
      expires_at     = new.not_after,
      ip_address     = coalesce(new.ip, public.sessions.ip_address),
      user_agent     = coalesce(new.user_agent, public.sessions.user_agent);

    return new;
  exception when others then
    raise warning 'sync_session_from_auth failed for %: %', new.id, sqlerrm;
    return coalesce(new, old);
  end;
end;
$$;

-- 3) Attach to auth.sessions for the full lifecycle.
drop trigger if exists trg_sync_session_from_auth on auth.sessions;
create trigger trg_sync_session_from_auth
  after insert or update or delete on auth.sessions
  for each row
  execute function public.sync_session_from_auth();
