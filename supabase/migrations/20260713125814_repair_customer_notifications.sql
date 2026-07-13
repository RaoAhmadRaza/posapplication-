-- C4 — Customer status notifications (RepairStatusChanged → customer).
-- Customers aren't users, so this does NOT use notifications. It records an
-- outbound INTENT in communication_logs. Actual SMS/email delivery is DEFERRED
-- to the M11 provider/worker; until then rows sit status='PENDING'.
-- Template body (REPAIR_STATUS) is owned by the M11 sender — we log only the
-- template_code + payload here (no separate template table yet, YAGNI).

create table if not exists public.communication_logs (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  customer_id uuid not null references public.customers(id),
  channel text not null check (channel in ('SMS', 'EMAIL')),
  template_code text not null,
  status text not null default 'PENDING'
    check (status in ('PENDING', 'QUEUED', 'SENT', 'FAILED')),
  recipient text,                               -- phone/email captured at log time
  payload jsonb not null default '{}'::jsonb,
  error text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

create index if not exists idx_comm_logs_tenant
  on public.communication_logs (tenant_id, created_at desc);
create index if not exists idx_comm_logs_customer
  on public.communication_logs (customer_id);

alter table public.communication_logs enable row level security;
drop policy if exists "cl tenant read" on public.communication_logs;
create policy "cl tenant read" on public.communication_logs for select to authenticated
  using (tenant_id = public.auth_tenant_id());
-- Written only by change_repair_status (security definer) + the future M11 worker
-- (service_role). No direct client writes.
revoke insert, update, delete on public.communication_logs from authenticated;

-- Redefine the SOLE status writer: keep everything, ADD a best-effort customer
-- dispatch after the history insert. A comms failure must NEVER block the status
-- change (own exception block, swallowed).
create or replace function public.change_repair_status(p_repair_id uuid, p_new_status repair_status_enum, p_notes text)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_old repair_status_enum; v_tech uuid; v_num text; v_ok boolean;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('repair','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select status, technician_id, job_number into v_old, v_tech, v_num
    from repair_jobs where id=p_repair_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_JOB_NOT_FOUND'; end if;
  if v_old = p_new_status then raise exception 'ERR_SAME_STATUS'; end if;

  -- transitions (RECEIVED→DIAGNOSED→AWAITING_APPROVAL→IN_REPAIR→QC→READY→[DELIVERED via close]);
  -- CANCELLED from any non-terminal; WARRANTY_CLAIM from DELIVERED.
  v_ok := case
    when p_new_status='CANCELLED' and v_old not in ('DELIVERED','CANCELLED') then true
    when p_new_status='WARRANTY_CLAIM' and v_old='DELIVERED' then true
    when v_old='RECEIVED'          and p_new_status in ('DIAGNOSED','IN_REPAIR') then true
    when v_old='DIAGNOSED'         and p_new_status in ('AWAITING_APPROVAL','IN_REPAIR') then true
    when v_old='AWAITING_APPROVAL' and p_new_status in ('IN_REPAIR','CANCELLED') then true
    when v_old='IN_REPAIR'         and p_new_status in ('QC','READY') then true
    when v_old='QC'                and p_new_status in ('READY','IN_REPAIR') then true
    when v_old='READY'             and p_new_status in ('IN_REPAIR') then true
    else false end;
  if p_new_status='DELIVERED' then raise exception 'ERR_USE_CLOSE_TO_DELIVER'; end if;
  if not v_ok then raise exception 'ERR_INVALID_TRANSITION: % -> %', v_old, p_new_status; end if;

  update repair_jobs set status=p_new_status, updated_by=v_uid, updated_at=now(), version=version+1 where id=p_repair_id;
  insert into repair_status_history (repair_id, old_status, new_status, changed_by, notes)
  values (p_repair_id, v_old, p_new_status, v_uid, p_notes);

  -- customer-facing outbound intent at status milestones (best-effort; must never
  -- block the status change). Delivery deferred to M11 → status stays PENDING.
  -- Only logs when the customer has a usable contact (phone→SMS, else email→EMAIL).
  if p_new_status in ('AWAITING_APPROVAL','READY') then
    begin
      insert into communication_logs (tenant_id, customer_id, channel, template_code, status, recipient, payload)
      select v_t, c.id,
             case when nullif(c.phone,'') is not null then 'SMS' else 'EMAIL' end,
             'REPAIR_STATUS', 'PENDING',
             coalesce(nullif(c.phone,''), nullif(c.email,'')),
             jsonb_build_object('job_number', v_num, 'status', p_new_status)
      from repair_jobs j join customers c on c.id=j.customer_id
      where j.id=p_repair_id
        and coalesce(nullif(c.phone,''), nullif(c.email,'')) is not null;
    exception when others then null;
    end;
  end if;

  -- in-app notification to the assigned technician (best-effort; must never block the status change)
  if v_tech is not null then
    begin
      insert into notifications (tenant_id, user_id, title, body, action_type, action_id, action_url)
      values (v_t, v_tech, 'Repair '||v_num||' → '||p_new_status, coalesce(p_notes,''),
              'REPAIR', p_repair_id, '/repair/'||p_repair_id::text);
    exception when others then null;
    end;
  end if;

  return jsonb_build_object('repair_id', p_repair_id, 'old_status', v_old, 'new_status', p_new_status);
end; $function$;
