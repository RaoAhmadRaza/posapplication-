-- ========== create_repair_job (intake) ==========
create or replace function public.create_repair_job(
  p_branch_id uuid, p_customer_id uuid, p_device_type varchar, p_device_brand varchar,
  p_device_model varchar, p_serial_no varchar, p_imei varchar, p_reported_issue text,
  p_priority varchar, p_estimated_cost numeric, p_signature_url varchar, p_notes text
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid(); v_id uuid; v_num text;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('repair','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not public.auth_has_branch(p_branch_id) then raise exception 'ERR_BRANCH_NOT_ASSIGNED' using errcode='42501'; end if;
  if not exists (select 1 from customers where id=p_customer_id and tenant_id=v_t and deleted_at is null) then raise exception 'ERR_CUSTOMER_NOT_FOUND'; end if;
  if p_reported_issue is null or length(trim(p_reported_issue))=0 then raise exception 'ERR_ISSUE_REQUIRED'; end if;

  v_num := public.next_number('REPAIR_JOB', p_branch_id);
  insert into repair_jobs (tenant_id, branch_id, customer_id, job_number, device_type, device_brand,
    device_model, serial_no, imei, reported_issue, status, priority, estimated_cost,
    customer_signature_url, notes, created_by, updated_by)
  values (v_t, p_branch_id, p_customer_id, v_num, p_device_type, p_device_brand, p_device_model,
    p_serial_no, p_imei, p_reported_issue, 'RECEIVED', coalesce(nullif(p_priority,''),'NORMAL'),
    p_estimated_cost, p_signature_url, p_notes, v_uid, v_uid)
  returning id into v_id;

  insert into repair_status_history (repair_id, old_status, new_status, changed_by, notes)
  values (v_id, null, 'RECEIVED', v_uid, 'Job created');

  return jsonb_build_object('repair_id', v_id, 'job_number', v_num, 'status', 'RECEIVED');
end; $function$;

-- ========== assign_technician ==========
create or replace function public.assign_technician(p_repair_id uuid, p_technician_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('repair','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not exists (select 1 from repair_jobs where id=p_repair_id and tenant_id=v_t and deleted_at is null) then raise exception 'ERR_JOB_NOT_FOUND'; end if;
  if not exists (select 1 from users where id=p_technician_id and tenant_id=v_t) then raise exception 'ERR_TECHNICIAN_NOT_FOUND'; end if;
  update repair_jobs set technician_id=p_technician_id, updated_by=v_uid, updated_at=now(), version=version+1 where id=p_repair_id;
  return jsonb_build_object('repair_id', p_repair_id, 'technician_id', p_technician_id);
end; $function$;

-- ========== set_repair_diagnosis (+ estimate + approval flag) ==========
create or replace function public.set_repair_diagnosis(
  p_repair_id uuid, p_diagnosis text, p_estimated_cost numeric, p_customer_approved boolean
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('repair','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not exists (select 1 from repair_jobs where id=p_repair_id and tenant_id=v_t and deleted_at is null) then raise exception 'ERR_JOB_NOT_FOUND'; end if;
  update repair_jobs set diagnosis=p_diagnosis, estimated_cost=coalesce(p_estimated_cost,estimated_cost),
    customer_approved=p_customer_approved, updated_by=v_uid, updated_at=now(), version=version+1
    where id=p_repair_id;
  return jsonb_build_object('repair_id', p_repair_id);
end; $function$;

-- ========== change_repair_status — SOLE status writer: validates transition, logs, notifies ==========
-- DELIVERED is NOT settable here (close_repair_job sets it — invoice must exist first).
-- Notification: in-app to the ASSIGNED TECHNICIAN. notifications.user_id is NOT NULL (a user FK) and there
-- is NO created_by column — customers aren't users, so customer-facing SMS/email stays deferred (M11).
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