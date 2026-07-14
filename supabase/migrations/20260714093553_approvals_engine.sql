-- upsert_approval_workflow: config CRUD. Validates levels_json shape. Gated approvals:update.
create or replace function public.upsert_approval_workflow(
  p_id uuid, p_type approval_workflow_type_enum, p_name varchar, p_description text,
  p_threshold_amount numeric, p_levels_json jsonb, p_escalation_ttl_hours int, p_is_active boolean
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id(); v_id uuid; v_lvl jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('approvals','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if p_levels_json is null or jsonb_typeof(p_levels_json) <> 'array' or jsonb_array_length(p_levels_json)=0 then raise exception 'ERR_LEVELS_REQUIRED'; end if;
  for v_lvl in select * from jsonb_array_elements(p_levels_json) loop
    if (v_lvl->>'level') is null or (v_lvl->>'required_role') is null then raise exception 'ERR_LEVEL_SHAPE (need level + required_role)'; end if;
  end loop;
  if p_id is null then
    insert into approval_workflows (tenant_id, workflow_type, name, description, threshold_amount, levels_json, escalation_ttl_hours, is_active)
    values (v_t, p_type, p_name, p_description, p_threshold_amount, p_levels_json, coalesce(p_escalation_ttl_hours,24), coalesce(p_is_active,true))
    returning id into v_id;
  else
    update approval_workflows set workflow_type=p_type, name=p_name, description=p_description,
      threshold_amount=p_threshold_amount, levels_json=p_levels_json,
      escalation_ttl_hours=coalesce(p_escalation_ttl_hours,escalation_ttl_hours), is_active=coalesce(p_is_active,is_active),
      updated_at=now(), version=version+1
      where id=p_id and tenant_id=v_t and deleted_at is null returning id into v_id;
    if v_id is null then raise exception 'ERR_WORKFLOW_NOT_FOUND'; end if;
  end if;
  return jsonb_build_object('workflow_id', v_id);
end; $function$;

-- request_approval: resolve the active workflow for (type, amount); create a PENDING request or report not-required.
-- Idempotent per open entity (unique index). SECURITY DEFINER — callable directly OR from another module RPC.
create or replace function public.request_approval(
  p_type approval_workflow_type_enum, p_entity_type varchar, p_entity_id uuid, p_amount numeric, p_reason text, p_correlation uuid
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid(); v_wf approval_workflows%rowtype; v_req uuid; v_existing approval_requests%rowtype;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  -- already an open request for this entity? return it (idempotent)
  select * into v_existing from approval_requests where entity_type=p_entity_type and entity_id=p_entity_id and status in ('PENDING','ESCALATED') and tenant_id=v_t;
  if found then return jsonb_build_object('required', true, 'request_id', v_existing.id, 'status', v_existing.status, 'existing', true); end if;
  -- pick the active workflow whose threshold applies (NULL threshold = always; else amount >= threshold); highest threshold wins
  select * into v_wf from approval_workflows
    where tenant_id=v_t and workflow_type=p_type and is_active and deleted_at is null
      and (threshold_amount is null or coalesce(p_amount,0) >= threshold_amount)
    order by threshold_amount desc nulls last limit 1;
  if not found then return jsonb_build_object('required', false); end if;   -- no workflow → caller proceeds as today
  insert into approval_requests (tenant_id, workflow_id, entity_type, entity_id, requestor_id, status, current_level, amount, reason, expires_at, correlation_id)
  values (v_t, v_wf.id, p_entity_type, p_entity_id, v_uid, 'PENDING', 1, p_amount, p_reason, now() + make_interval(hours => v_wf.escalation_ttl_hours), p_correlation)
  returning id into v_req;
  return jsonb_build_object('required', true, 'request_id', v_req, 'status', 'PENDING', 'workflow_id', v_wf.id);
end; $function$;

-- act_on_approval: APPROVE/REJECT at the current level. Gated approvals:approve + the level's required_role.
-- On enough approvals for the level (min_approvers), advance; past the last level → APPROVED. REJECT → REJECTED.
create or replace function public.act_on_approval(p_request_id uuid, p_action varchar, p_comments text)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid(); v_req approval_requests%rowtype; v_wf approval_workflows%rowtype;
  v_lvl jsonb; v_role text; v_min int; v_cnt int; v_is_admin boolean; v_has_role boolean; v_levels int; v_newstatus approval_status_enum;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('approvals','approve') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if upper(p_action) not in ('APPROVED','REJECTED') then raise exception 'ERR_BAD_ACTION'; end if;
  select * into v_req from approval_requests where id=p_request_id and tenant_id=v_t;
  if not found then raise exception 'ERR_REQUEST_NOT_FOUND'; end if;
  if v_req.status not in ('PENDING','ESCALATED') then raise exception 'ERR_NOT_OPEN'; end if;
  select * into v_wf from approval_workflows where id=v_req.workflow_id;
  v_lvl := (select e from jsonb_array_elements(v_wf.levels_json) e where (e->>'level')::int = v_req.current_level limit 1);
  if v_lvl is null then raise exception 'ERR_LEVEL_NOT_DEFINED'; end if;
  v_role := v_lvl->>'required_role'; v_min := coalesce((v_lvl->>'min_approvers')::int, 1);
  -- role check (ADMIN is super-approver). Confirm the users→role resolution in A0.4 matches this join.
  select exists(select 1 from users u join roles r on r.id=u.role_id where u.id=v_uid and r.name='ADMIN') into v_is_admin;
  select exists(select 1 from users u join roles r on r.id=u.role_id where u.id=v_uid and r.name=v_role) into v_has_role;
  if not (v_is_admin or v_has_role) then raise exception 'ERR_ROLE_NOT_ALLOWED for level %', v_req.current_level; end if;
  -- one action per actor per level
  if exists (select 1 from approval_actions where request_id=p_request_id and actor_id=v_uid and level=v_req.current_level) then raise exception 'ERR_ALREADY_ACTED'; end if;

  insert into approval_actions (request_id, actor_id, action, level, comments) values (p_request_id, v_uid, upper(p_action), v_req.current_level, p_comments);

  if upper(p_action)='REJECTED' then
    update approval_requests set status='REJECTED', completed_at=now(), updated_at=now(), version=version+1 where id=p_request_id;
    return jsonb_build_object('request_id', p_request_id, 'status', 'REJECTED');
  end if;

  -- approvals at this level so far
  select count(*) into v_cnt from approval_actions where request_id=p_request_id and level=v_req.current_level and action='APPROVED';
  v_levels := jsonb_array_length(v_wf.levels_json);
  if v_cnt >= v_min then
    if v_req.current_level >= v_levels then
      update approval_requests set status='APPROVED', completed_at=now(), updated_at=now(), version=version+1 where id=p_request_id;
      v_newstatus := 'APPROVED';
    else
      update approval_requests set current_level=current_level+1, expires_at=now()+make_interval(hours => v_wf.escalation_ttl_hours), updated_at=now(), version=version+1 where id=p_request_id;
      v_newstatus := 'PENDING';
    end if;
  else
    v_newstatus := v_req.status;   -- still need more approvers at this level
  end if;
  return jsonb_build_object('request_id', p_request_id, 'status', v_newstatus, 'level', (select current_level from approval_requests where id=p_request_id));
end; $function$;

-- cancel_approval_request: requestor or admin cancels an OPEN request (e.g. the PO was withdrawn).
create or replace function public.cancel_approval_request(p_request_id uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid(); v_req approval_requests%rowtype; v_is_admin boolean;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  select * into v_req from approval_requests where id=p_request_id and tenant_id=v_t;
  if not found then raise exception 'ERR_REQUEST_NOT_FOUND'; end if;
  if v_req.status not in ('PENDING','ESCALATED') then raise exception 'ERR_NOT_OPEN'; end if;
  select exists(select 1 from users u join roles r on r.id=u.role_id where u.id=v_uid and r.name='ADMIN') into v_is_admin;
  if not (v_is_admin or v_req.requestor_id=v_uid) then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  update approval_requests set status='CANCELLED', completed_at=now(), updated_at=now(), version=version+1 where id=p_request_id;
  insert into approval_actions (request_id, actor_id, action, level, comments) values (p_request_id, v_uid, 'CANCELLED', v_req.current_level, p_reason);
  return jsonb_build_object('request_id', p_request_id, 'status', 'CANCELLED');
end; $function$;

-- approval_status: helper for caller modules — latest request status for an entity ('NONE' if never requested).
create or replace function public.approval_status(p_entity_type varchar, p_entity_id uuid)
returns jsonb language sql stable security definer set search_path to 'public' as $$
  select coalesce(
    (select jsonb_build_object('request_id', id, 'status', status, 'current_level', current_level)
       from approval_requests where entity_type=p_entity_type and entity_id=p_entity_id and tenant_id=public.auth_tenant_id()
       order by created_at desc limit 1),
    jsonb_build_object('status','NONE'));
$$;