-- create_employee: manual employee_code (unique-checked). Gated hr:create.
create or replace function public.create_employee(
  p_branch_id uuid, p_employee_code varchar, p_name varchar, p_cnic varchar, p_phone varchar, p_email varchar,
  p_address text, p_designation varchar, p_department varchar, p_joining_date date, p_salary_type salary_type_enum,
  p_base_salary numeric, p_bank_name varchar, p_bank_account_number varchar, p_user_id uuid, p_notes text
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid(); v_id uuid;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('hr','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not public.auth_has_branch(p_branch_id) then raise exception 'ERR_BRANCH_NOT_ASSIGNED' using errcode='42501'; end if;
  if p_employee_code is null or length(trim(p_employee_code))=0 then raise exception 'ERR_CODE_REQUIRED'; end if;
  if exists (select 1 from employees where tenant_id=v_t and employee_code=p_employee_code and deleted_at is null) then raise exception 'ERR_CODE_TAKEN'; end if;
  insert into employees (tenant_id, branch_id, user_id, employee_code, name, cnic, phone, email, address,
    designation, department, joining_date, salary_type, base_salary, bank_name, bank_account_number, notes,
    created_by, updated_by)
  values (v_t, p_branch_id, p_user_id, p_employee_code, p_name, p_cnic, p_phone, p_email, p_address,
    p_designation, p_department, p_joining_date, coalesce(p_salary_type,'MONTHLY'), coalesce(p_base_salary,0),
    p_bank_name, p_bank_account_number, p_notes, v_uid, v_uid)
  returning id into v_id;
  return jsonb_build_object('employee_id', v_id, 'employee_code', p_employee_code);
end; $function$;

-- update_employee: partial update via COALESCE. Gated hr:update.
create or replace function public.update_employee(
  p_employee_id uuid, p_name varchar, p_phone varchar, p_email varchar, p_address text, p_designation varchar,
  p_department varchar, p_salary_type salary_type_enum, p_base_salary numeric, p_bank_name varchar,
  p_bank_account_number varchar, p_status employee_status_enum, p_notes text
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid();
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('hr','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not exists (select 1 from employees where id=p_employee_id and tenant_id=v_t and deleted_at is null) then raise exception 'ERR_EMP_NOT_FOUND'; end if;
  update employees set
    name=coalesce(p_name,name), phone=coalesce(p_phone,phone), email=coalesce(p_email,email),
    address=coalesce(p_address,address), designation=coalesce(p_designation,designation),
    department=coalesce(p_department,department), salary_type=coalesce(p_salary_type,salary_type),
    base_salary=coalesce(p_base_salary,base_salary), bank_name=coalesce(p_bank_name,bank_name),
    bank_account_number=coalesce(p_bank_account_number,bank_account_number), status=coalesce(p_status,status),
    notes=coalesce(p_notes,notes), updated_by=v_uid, updated_at=now(), version=version+1
    where id=p_employee_id;
  return jsonb_build_object('employee_id', p_employee_id);
end; $function$;

-- terminate_employee: status + termination_date. Final settlement flagged (see Deferred). Gated hr:update.
create or replace function public.terminate_employee(p_employee_id uuid, p_termination_date date, p_status employee_status_enum, p_notes text)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid();
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('hr','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if p_status not in ('TERMINATED','RESIGNED') then raise exception 'ERR_BAD_TERMINATION_STATUS'; end if;
  update employees set status=p_status, termination_date=coalesce(p_termination_date,current_date),
    notes=coalesce(p_notes,notes), updated_by=v_uid, updated_at=now(), version=version+1
    where id=p_employee_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_EMP_NOT_FOUND'; end if;
  return jsonb_build_object('employee_id', p_employee_id, 'status', p_status);
end; $function$;

-- upsert_shift: shifts writes go through RLS (hr:update) directly OR this helper for validation.
create or replace function public.upsert_shift(p_id uuid, p_name varchar, p_start time, p_end time, p_grace int, p_break int, p_active boolean)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id(); v_id uuid;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('hr','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if p_id is null then
    insert into shifts (tenant_id, name, start_time, end_time, grace_minutes, break_minutes, is_active)
    values (v_t, p_name, p_start, p_end, coalesce(p_grace,15), coalesce(p_break,60), coalesce(p_active,true))
    returning id into v_id;
  else
    update shifts set name=p_name, start_time=p_start, end_time=p_end, grace_minutes=coalesce(p_grace,grace_minutes),
      break_minutes=coalesce(p_break,break_minutes), is_active=coalesce(p_active,is_active), updated_at=now()
      where id=p_id and tenant_id=v_t returning id into v_id;
    if v_id is null then raise exception 'ERR_SHIFT_NOT_FOUND'; end if;
  end if;
  return jsonb_build_object('shift_id', v_id);
end; $function$;