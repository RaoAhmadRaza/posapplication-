-- Cluster H: no table was ever in the supabase_realtime publication (grep of all
-- migrations found zero ALTER PUBLICATION), so Postgres emitted no change events
-- and the app's new client subscriptions would have nothing to consume — devices
-- / sessions / security-log / permission changes stayed stale until app reopen
-- (DEVICES-001/002/003, SETTINGS-007) and permission changes never reached a
-- logged-in session (K.2).
--
-- Add only the tables the UI live-updates. Realtime respects RLS: each subscriber
-- receives only rows its row-level policy allows to SELECT, so the stream is
-- tenant/user-scoped exactly like a normal read — the policy is the isolation
-- boundary. REPLICA IDENTITY FULL is set so DELETE events carry the old row's
-- scoping columns (tenant_id/user_id), letting RLS evaluate them; without it a
-- delete would only expose the PK and RLS could not filter it.
--
-- Idempotent: skip any table already published, and REPLICA IDENTITY FULL is a
-- no-op if already set. Rollback = ALTER PUBLICATION ... DROP TABLE per table.

do $$
declare
  t text;
begin
  foreach t in array array['devices', 'sessions', 'audit_logs', 'permissions']
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I', t);
    end if;
    execute format('alter table public.%I replica identity full', t);
  end loop;
end $$;
