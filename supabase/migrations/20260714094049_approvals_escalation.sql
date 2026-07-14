-- escalate_expired_approvals: PENDING past expires_at → ESCALATED (+ audit + escalated_at). Also EXPIRE optional.
-- Runs as a batch; returns count. Definer so a scheduler (service_role) or an admin can call it.
create or replace function public.escalate_expired_approvals()
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_esc int;
begin
  with due as (
    select id from approval_requests where status='PENDING' and expires_at is not null and expires_at < now()
  ), upd as (
    update approval_requests r set status='ESCALATED', escalated_at=now(), updated_at=now(), version=version+1
    from due where r.id=due.id returning r.id, r.current_level
  ), aud as (
    insert into approval_actions (request_id, actor_id, action, level, comments)
    select u.id, r.requestor_id, 'ESCALATED', u.current_level, 'Auto-escalated (TTL)'
    from upd u join approval_requests r on r.id=u.id
  )
  select count(*) into v_esc from upd;
  return jsonb_build_object('escalated', v_esc);
end; $function$;