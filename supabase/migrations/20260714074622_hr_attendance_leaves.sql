-- ========== attendance — verbatim §3.10 ==========
create table if not exists public.attendance (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  employee_id uuid not null references public.employees(id),
  shift_id uuid references public.shifts(id),
  date date not null,
  check_in timestamptz,
  check_out timestamptz,
  status attendance_status_enum not null default 'PRESENT',
  overtime_hours decimal(5,2) not null default 0,
  late_minutes integer not null default 0,
  early_leave_minutes integer not null default 0,
  source varchar(50) not null default 'MANUAL',
  gps_location point,
  device_id uuid references public.devices(id),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  created_by uuid references public.users(id),
  updated_by uuid references public.users(id)
);
create unique index if not exists uq_attendance_employee_date on public.attendance(employee_id, date);
create index if not exists idx_attendance_tenant_date on public.attendance(tenant_id, date);
create index if not exists idx_attendance_status on public.attendance(tenant_id, status, date);

-- ========== leaves — verbatim §3.10 ==========
create table if not exists public.leaves (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  employee_id uuid not null references public.employees(id),
  type leave_type_enum not null,
  from_date date not null,
  to_date date not null,
  days decimal(5,1) not null,
  reason text,
  status leave_status_enum not null default 'PENDING',
  approved_by uuid references public.users(id),
  approved_at timestamptz,
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  created_by uuid references public.users(id)
);
create index if not exists idx_leaves_employee on public.leaves(employee_id, from_date);
create index if not exists idx_leaves_status on public.leaves(tenant_id, status);
create index if not exists idx_leaves_pending on public.leaves(tenant_id) where status='PENDING';
do $$ begin alter table public.leaves add constraint chk_leaves_dates check (to_date >= from_date); exception when duplicate_object then null; end $$;
do $$ begin alter table public.leaves add constraint chk_leaves_days check (days > 0); exception when duplicate_object then null; end $$;

-- RLS
alter table public.attendance enable row level security;
drop policy if exists "att tenant read" on public.attendance;
create policy "att tenant read" on public.attendance for select to authenticated using (tenant_id=public.auth_tenant_id());
revoke insert, update, delete on public.attendance from authenticated;   -- via RPCs only (audit: soft edit + reason)
alter table public.leaves enable row level security;
drop policy if exists "lv tenant read" on public.leaves;
create policy "lv tenant read" on public.leaves for select to authenticated using (tenant_id=public.auth_tenant_id());
revoke insert, update, delete on public.leaves from authenticated;

-- mark_attendance: upsert by (employee_id, date). Computes late/early vs shift. Audit: edits require a reason.
create or replace function public.mark_attendance(
  p_employee_id uuid, p_date date, p_shift_id uuid, p_check_in timestamptz, p_check_out timestamptz,
  p_status attendance_status_enum, p_overtime_hours numeric, p_source varchar, p_notes text
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid(); v_id uuid; v_late int:=0; v_early int:=0;
        v_start time; v_grace int; v_end time; v_exists boolean;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('hr','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not exists (select 1 from employees where id=p_employee_id and tenant_id=v_t and deleted_at is null) then raise exception 'ERR_EMP_NOT_FOUND'; end if;
  select exists(select 1 from attendance where employee_id=p_employee_id and date=p_date) into v_exists;
  if v_exists and (p_notes is null or length(trim(p_notes))=0) then raise exception 'ERR_EDIT_REASON_REQUIRED'; end if;  -- audit rule
  if p_shift_id is not null and p_check_in is not null then
    select start_time, grace_minutes, end_time into v_start, v_grace, v_end from shifts where id=p_shift_id and tenant_id=v_t;
    v_late := greatest(0, floor(extract(epoch from (p_check_in::time - v_start))/60)::int - coalesce(v_grace,0));
    if p_check_out is not null then v_early := greatest(0, floor(extract(epoch from (v_end - p_check_out::time))/60)::int); end if;
  end if;
  insert into attendance (tenant_id, employee_id, shift_id, date, check_in, check_out, status, overtime_hours,
    late_minutes, early_leave_minutes, source, notes, created_by, updated_by)
  values (v_t, p_employee_id, p_shift_id, p_date, p_check_in, p_check_out, coalesce(p_status,'PRESENT'),
    coalesce(p_overtime_hours,0), v_late, v_early, coalesce(p_source,'MANUAL'), p_notes, v_uid, v_uid)
  on conflict (employee_id, date) do update set
    shift_id=excluded.shift_id, check_in=excluded.check_in, check_out=excluded.check_out, status=excluded.status,
    overtime_hours=excluded.overtime_hours, late_minutes=excluded.late_minutes,
    early_leave_minutes=excluded.early_leave_minutes, source=excluded.source, notes=excluded.notes,
    updated_by=v_uid, updated_at=now(), version=attendance.version+1
  returning id into v_id;
  return jsonb_build_object('attendance_id', v_id, 'late_minutes', v_late, 'early_leave_minutes', v_early);
end; $function$;

-- apply_leave (employee/HR raises a PENDING request; days computed if not supplied)
create or replace function public.apply_leave(p_employee_id uuid, p_type leave_type_enum, p_from date, p_to date, p_days numeric, p_reason text)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid(); v_id uuid; v_days numeric;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('hr','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not exists (select 1 from employees where id=p_employee_id and tenant_id=v_t and deleted_at is null) then raise exception 'ERR_EMP_NOT_FOUND'; end if;
  v_days := coalesce(p_days, (p_to - p_from) + 1);
  if v_days <= 0 then raise exception 'ERR_BAD_DAYS'; end if;
  insert into leaves (tenant_id, employee_id, type, from_date, to_date, days, reason, status, created_by)
  values (v_t, p_employee_id, p_type, p_from, p_to, v_days, p_reason, 'PENDING', v_uid)
  returning id into v_id;
  return jsonb_build_object('leave_id', v_id, 'days', v_days, 'status', 'PENDING');
end; $function$;

-- decide_leave: approve/reject. Gated hr:approve. On approve, stamps ON_LEAVE attendance across the range.
create or replace function public.decide_leave(p_leave_id uuid, p_approve boolean, p_rejection_reason text)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid(); v_lv leaves%rowtype; d date;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('hr','approve') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select * into v_lv from leaves where id=p_leave_id and tenant_id=v_t;
  if not found then raise exception 'ERR_LEAVE_NOT_FOUND'; end if;
  if v_lv.status <> 'PENDING' then raise exception 'ERR_LEAVE_NOT_PENDING'; end if;
  if p_approve then
    update leaves set status='APPROVED', approved_by=v_uid, approved_at=now(), updated_at=now(), version=version+1 where id=p_leave_id;
    -- stamp ON_LEAVE attendance across the range (best-effort; reason carried so the audit-edit guard is satisfied)
    d := v_lv.from_date;
    while d <= v_lv.to_date loop
      insert into attendance (tenant_id, employee_id, date, status, source, notes, created_by, updated_by)
      values (v_t, v_lv.employee_id, d, 'ON_LEAVE', 'LEAVE', 'Leave '||p_leave_id::text, v_uid, v_uid)
      on conflict (employee_id, date) do update set status='ON_LEAVE', notes='Leave '||p_leave_id::text, updated_by=v_uid, updated_at=now(), version=attendance.version+1;
      d := d + 1;
    end loop;
  else
    update leaves set status='REJECTED', approved_by=v_uid, approved_at=now(), rejection_reason=p_rejection_reason, updated_at=now(), version=version+1 where id=p_leave_id;
  end if;
  return jsonb_build_object('leave_id', p_leave_id, 'status', case when p_approve then 'APPROVED' else 'REJECTED' end);
end; $function$;