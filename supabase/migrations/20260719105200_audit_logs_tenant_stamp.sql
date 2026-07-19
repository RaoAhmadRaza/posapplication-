-- Cluster I (audit_logs half): every audit_logs row was written with tenant_id
-- NULL, because the client insert (auth_remote_datasource.insertAuditLog) never
-- set it. The read policy "audit tenant read" filters tenant_id = auth_tenant_id(),
-- which never matches NULL — so every row was permanently invisible in
-- /security-logs (SECURITY-LOGS-001/002).
--
-- Fix is write-side only (the read policy is correct and stays untouched — a NULL
-- must never be readable, that is the tenant-isolation floor). We stamp tenant_id
-- server-side from auth_tenant_id() rather than trusting the client:
--   1. A BEFORE INSERT trigger forces tenant_id := auth_tenant_id(), ignoring any
--      client-supplied value. Unspoofable, fixes all 6 AuditService call sites at
--      once, and no client round-trip.
--   2. The insert policy is tightened to also require tenant_id = auth_tenant_id().
--      Previously it checked only user_id = auth.uid(), which let a client forge a
--      row into ANOTHER tenant's audit trail (audit-log injection — the forged row
--      would surface under the victim's read policy). The trigger guarantees the
--      row satisfies this check; RLS WITH CHECK runs after BEFORE triggers.
--
-- Historical NULL rows are left as-is (not backfilled): they predate any reliable
-- tenant attribution and are not security-critical to surface retroactively.

create or replace function public.set_audit_tenant()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  new.tenant_id := public.auth_tenant_id();
  return new;
end;
$$;

drop trigger if exists trg_set_audit_tenant on public.audit_logs;
create trigger trg_set_audit_tenant
  before insert on public.audit_logs
  for each row
  execute function public.set_audit_tenant();

drop policy if exists "audit self insert" on public.audit_logs;
create policy "audit self insert" on public.audit_logs
  for insert to authenticated
  with check (user_id = auth.uid() and tenant_id = public.auth_tenant_id());
