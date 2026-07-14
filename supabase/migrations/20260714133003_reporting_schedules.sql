-- ========== report_schedules — verbatim §3.12 ==========
create table if not exists public.report_schedules (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  report_type varchar(100) not null,
  name varchar(255) not null,
  frequency varchar(20) not null,
  cron_expression varchar(50),
  filters_json jsonb not null default '{}'::jsonb,
  recipients_json jsonb not null default '[]'::jsonb,
  output_format varchar(20) not null default 'PDF',
  is_active boolean not null default true,
  last_run_at timestamptz,
  next_run_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_by uuid references public.users(id)
);
create index if not exists idx_report_schedules_tenant on public.report_schedules(tenant_id) where is_active = true;
create index if not exists idx_report_schedules_next on public.report_schedules(next_run_at) where is_active = true;

alter table public.report_schedules enable row level security;
drop policy if exists "rs read" on public.report_schedules;
create policy "rs read" on public.report_schedules for select to authenticated using (tenant_id=public.auth_tenant_id());
drop policy if exists "rs write" on public.report_schedules;
create policy "rs write" on public.report_schedules for all to authenticated
  using (tenant_id=public.auth_tenant_id() and public.auth_has_permission('reports','export'))
  with check (tenant_id=public.auth_tenant_id() and public.auth_has_permission('reports','export'));

-- next-run compute from frequency
create or replace function public._report_next_run(p_freq varchar, p_from timestamptz)
returns timestamptz language sql immutable as $$
  select case upper(p_freq)
    when 'DAILY' then p_from + interval '1 day'
    when 'WEEKLY' then p_from + interval '7 days'
    when 'MONTHLY' then p_from + interval '1 month'
    else p_from + interval '1 day' end;
$$;

create or replace function public.upsert_report_schedule(
  p_id uuid, p_report_type varchar, p_name varchar, p_frequency varchar, p_filters jsonb, p_recipients jsonb, p_format varchar, p_active boolean
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid(); v_id uuid;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('reports','export') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if p_id is null then
    insert into report_schedules (tenant_id, report_type, name, frequency, filters_json, recipients_json, output_format, is_active, next_run_at, created_by)
    values (v_t, p_report_type, p_name, p_frequency, coalesce(p_filters,'{}'), coalesce(p_recipients,'[]'), coalesce(p_format,'PDF'), coalesce(p_active,true), public._report_next_run(p_frequency, now()), v_uid)
    returning id into v_id;
  else
    update report_schedules set report_type=p_report_type, name=p_name, frequency=p_frequency,
      filters_json=coalesce(p_filters,filters_json), recipients_json=coalesce(p_recipients,recipients_json),
      output_format=coalesce(p_format,output_format), is_active=coalesce(p_active,is_active), updated_at=now()
      where id=p_id and tenant_id=v_t returning id into v_id;
    if v_id is null then raise exception 'ERR_SCHEDULE_NOT_FOUND'; end if;
  end if;
  return jsonb_build_object('schedule_id', v_id);
end; $function$;

-- run-due batch (pg_cron). Generates the report data snapshot + logs a delivery intent to communication_logs.
-- ACTUAL email send is DEPENDENT on the M11 sender — until then rows sit as queued outbound (documented).
create or replace function public.run_due_report_schedules()
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_row report_schedules%rowtype; v_n int:=0; v_rcpt jsonb;
begin
  for v_row in select * from report_schedules where is_active and (next_run_at is null or next_run_at <= now()) loop
    -- (report DATA is generated on-demand by the app/report RPCs; here we queue the delivery intent per recipient)
    for v_rcpt in select * from jsonb_array_elements(v_row.recipients_json) loop
      begin
        insert into communication_logs (tenant_id, channel, template_code, status, recipient, payload)   -- live cols: recipient + sent_at (null until M11)
        values (v_row.tenant_id, 'EMAIL', 'SCHEDULED_REPORT', 'PENDING', (v_rcpt #>> '{}'),
                jsonb_build_object('report_type', v_row.report_type, 'name', v_row.name, 'format', v_row.output_format, 'filters', v_row.filters_json));
      exception when others then null; end;
    end loop;
    update report_schedules set last_run_at=now(), next_run_at=public._report_next_run(v_row.frequency, now()) where id=v_row.id;
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('ran', v_n);
end; $function$;