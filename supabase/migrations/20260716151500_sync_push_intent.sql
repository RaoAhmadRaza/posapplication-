-- Client push into the server outbox. sync_outbox has NO insert policy (RPC-only writes, D2), and
-- sync_replay_sale_intent (D5) only operates on an EXISTING row — so a device had no way to enqueue its
-- local intent server-side. This is that missing step: definer, idempotent on (tenant_id, idempotency_key),
-- returns the outbox id + current status. Re-pushing the SAME key (double-drain / app killed mid-drain)
-- returns the SAME row — the first half of "drain twice → 3 invoices, not 6" (the second half is the replay
-- guard + create_sale's idempotency key).
create or replace function public.sync_push_intent(
  p_idempotency_key   uuid,
  p_branch_id         uuid,
  p_payload           jsonb,
  p_client_created_at timestamptz,
  p_local_ref         text,
  p_device_id         uuid default null
) returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_t uuid := public.auth_tenant_id();
  v_uid uuid := auth.uid();
  v_id uuid;
  v_status sync_intent_status_enum;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('sales','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not public.auth_has_branch(p_branch_id) then raise exception 'ERR_BRANCH_NOT_ASSIGNED' using errcode='42501'; end if;

  insert into public.sync_outbox (tenant_id, branch_id, device_id, user_id, idempotency_key,
                                  intent_type, payload_json, client_created_at, local_ref)
  values (v_t, p_branch_id, p_device_id, v_uid, p_idempotency_key,
          'SALE', p_payload, p_client_created_at, p_local_ref)
  on conflict (tenant_id, idempotency_key) do nothing;

  select id, status into v_id, v_status
    from public.sync_outbox where tenant_id = v_t and idempotency_key = p_idempotency_key;

  return jsonb_build_object('outbox_id', v_id, 'status', v_status);
end; $$;

revoke execute on function public.sync_push_intent(uuid, uuid, jsonb, timestamptz, text, uuid) from public, anon;
grant execute on function public.sync_push_intent(uuid, uuid, jsonb, timestamptz, text, uuid) to authenticated, service_role;
