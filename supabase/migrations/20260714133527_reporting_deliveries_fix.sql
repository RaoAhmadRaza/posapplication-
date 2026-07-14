-- FIX: run_due_report_schedules targeted communication_logs (customer_id NOT NULL, CRM-scoped) → every
-- insert threw 23502 and was silently swallowed by `exception when others then null`, so nothing queued.
-- Reports aren't customer messages: give them a dedicated tenant-scoped delivery table + repoint the runner.

create table if not exists public.report_deliveries (
  id          uuid primary key default gen_random_uuid(),
  tenant_id   uuid not null,
  schedule_id uuid references public.report_schedules(id) on delete set null,
  channel     text not null default 'EMAIL',
  format      text,
  status      text not null default 'PENDING',
  recipient   text not null,
  payload     jsonb not null default '{}'::jsonb,
  error       text,
  created_at  timestamptz not null default now(),
  sent_at     timestamptz
);
create index if not exists ix_report_deliveries_tenant_status on public.report_deliveries(tenant_id, status);

alter table public.report_deliveries enable row level security;
-- Read-only for authenticated within own tenant (needs reports:read). Writes happen via the SECURITY DEFINER
-- runner (bypasses RLS) and the future M11 sender (service_role) — never directly from the app.
drop policy if exists report_deliveries_select on public.report_deliveries;
create policy report_deliveries_select on public.report_deliveries for select to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('reports','read'));
revoke insert, update, delete on public.report_deliveries from authenticated;

-- Repoint the runner: insert a PENDING delivery per recipient, advance next_run_at. No blanket exception-swallow.
create or replace function public.run_due_report_schedules()
 returns jsonb language plpgsql security definer set search_path to 'public'
as $function$
declare v_row report_schedules%rowtype; v_n int:=0; v_rcpt jsonb;
begin
  for v_row in select * from report_schedules where is_active and (next_run_at is null or next_run_at <= now()) loop
    -- report DATA is generated on-demand by the app/report RPCs; here we queue the delivery intent per recipient
    for v_rcpt in select * from jsonb_array_elements(v_row.recipients_json) loop
      insert into report_deliveries (tenant_id, schedule_id, channel, format, status, recipient, payload)
      values (v_row.tenant_id, v_row.id, 'EMAIL', v_row.output_format, 'PENDING', (v_rcpt #>> '{}'),
              jsonb_build_object('report_type', v_row.report_type, 'name', v_row.name,
                                 'format', v_row.output_format, 'filters', v_row.filters_json));
    end loop;
    update report_schedules set last_run_at=now(), next_run_at=public._report_next_run(v_row.frequency, now())
    where id=v_row.id;
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ran', v_n);
end; $function$;
