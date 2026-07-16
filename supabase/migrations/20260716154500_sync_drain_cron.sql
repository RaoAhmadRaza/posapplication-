-- Cron-safe server drain. A pg_cron job runs with NO request.jwt.claims, so a naive
-- `select sync_replay_sale_intent(id) ...` mass-FAILs: create_sale reads auth.uid()/auth_tenant_id()
-- from the JWT → NULL → ERR_NO_TENANT on every row (verified). This wrapper impersonates each intent's
-- ORIGINAL cashier (SET request.jwt.claims from user_id) so create_sale resolves the right tenant,
-- permissions and branch, then routes through the UNCHANGED sync_replay_sale_intent (sole-writer path;
-- its idempotency + terminal/transient classification are reused verbatim). Serial, oldest-first.
--
-- PRIVILEGED: impersonates users → granted to service_role ONLY (+ postgres owner for the cron job);
-- NOT authenticated/anon.
create or replace function public.sync_drain_cron(p_limit int default 50)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  r record;
  v_res jsonb;
  v_applied int := 0; v_abandoned int := 0; v_failed int := 0;
begin
  for r in
    select id, user_id from public.sync_outbox
     where status in ('PENDING'::sync_intent_status_enum, 'FAILED'::sync_intent_status_enum)
       and attempts < 5
     order by client_created_at
     limit p_limit
  loop
    if r.user_id is null then
      continue; -- cannot resolve a tenant/actor for this row; leave it for a human
    end if;
    -- impersonate the row's cashier for this iteration (txn-local GUC)
    perform set_config('request.jwt.claims',
      json_build_object('sub', r.user_id, 'role', 'authenticated')::text, true);
    v_res := public.sync_replay_sale_intent(r.id);
    if (v_res->>'applied') = 'true' then v_applied := v_applied + 1;
    elsif (v_res->>'terminal') = 'true' then v_abandoned := v_abandoned + 1;
    else v_failed := v_failed + 1; end if;
  end loop;
  perform set_config('request.jwt.claims', null, true); -- clear impersonation
  return jsonb_build_object('applied', v_applied, 'abandoned', v_abandoned, 'failed', v_failed);
end $$;

revoke execute on function public.sync_drain_cron(int) from public, anon, authenticated;
grant execute on function public.sync_drain_cron(int) to service_role;
