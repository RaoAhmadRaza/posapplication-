-- Recoverable exceptions (the graveyard fix). Before this, an ABANDONED / FAILED-at-cap intent
-- was permanently outside the drain (status not in (PENDING,FAILED) or attempts >= 5) and
-- resolve_sync_exception only annotated the exception — the lost sale NEVER entered the books.
-- Neither fn is a money RPC (retry re-queues + delegates to sync_replay_sale_intent → create_sale).
--
-- Two changes, one coherent feature:
--   A. sync_replay_sale_intent — scope the exception-insert not-exists guard to OPEN rows only.
--      Without this, a retry that RESOLVES the old exception then fails AGAIN would be suppressed
--      (a RESOLVED row for this outbox_id exists) → silent again. OPEN-scoping re-surfaces it.
--   B. retry_sync_intent(p_outbox_id) — NEW, gated sync:resolve. Re-queues a stuck intent and
--      replays it server-side, impersonating the ORIGINAL cashier (correct attribution) exactly
--      like sync_drain_cron. SAFE BY CONSTRUCTION: uq_invoices_idem + create_sale's D4 key guard →
--      re-queueing cannot double-post; an already-applied intent returns its original invoice.
--      Inline replay (not pure re-queue) because a Centre exception is a SERVER row the client
--      drain can't reach (it drains the local sqflite queue) and sync_drain_cron is service_role
--      only — so without inline replay the admin would wait for the 5-min cron to recover a sale.

-- A. OPEN-scoped exception guard (D10 body verbatim + the one-line guard change) ------------------
create or replace function public.sync_replay_sale_intent(p_outbox_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_row sync_outbox; v_res jsonb; v_code text; v_terminal boolean; v_at_cap boolean;
begin
  select * into v_row from sync_outbox where id=p_outbox_id
    and status in ('PENDING'::sync_intent_status_enum,'FAILED'::sync_intent_status_enum)
    for update skip locked;
  if not found then return jsonb_build_object('skipped', true); end if;

  update sync_outbox set status='REPLAYING'::sync_intent_status_enum,
         attempts=attempts+1, updated_at=now() where id=v_row.id;

  begin
    v_res := create_sale(v_row.branch_id, (v_row.payload_json->>'customer_id')::uuid,
                         v_row.payload_json->'items', v_row.payload_json->'payments',
                         v_row.payload_json->>'notes', (v_row.payload_json->>'session_id')::uuid,
                         v_row.idempotency_key);
    update sync_outbox set status='APPLIED'::sync_intent_status_enum,
           invoice_id=(v_res->>'invoice_id')::uuid, applied_at=now(), updated_at=now() where id=v_row.id;
    update invoices set is_offline=true, synced_at=now(), device_id=v_row.device_id, local_ref=v_row.local_ref
     where id=(v_res->>'invoice_id')::uuid;
    return jsonb_build_object('applied', true, 'invoice_id', v_res->>'invoice_id');
  exception when others then
    v_code := coalesce(nullif(SQLERRM,''),'ERR_UNKNOWN');
    v_terminal := v_code ~ ('ERR_(INSUFFICIENT_STOCK|CREDIT_LIMIT_EXCEEDED|IMEI_NOT_AVAILABLE|BELOW_MIN_PRICE|'
                        || 'PRODUCT_NOT_FOUND|IMEI_REQUIRED|SERIALIZED_QTY_ONE|INVALID_QTY|EMPTY_CART|'
                        || 'PAYMENT_NONPOSITIVE|CREDIT_REQUIRES_CUSTOMER|NO_OPEN_SESSION|BRANCH_NOT_ASSIGNED|'
                        || 'NO_TENANT|PERMISSION_DENIED)');
    v_at_cap := (v_row.attempts + 1) >= 5;
    update sync_outbox set status = case when v_terminal then 'ABANDONED'::sync_intent_status_enum
                                         else 'FAILED'::sync_intent_status_enum end,
           last_error=v_code, updated_at=now() where id=v_row.id;
    if v_terminal or v_at_cap then
      -- OPEN-scoped: a prior RESOLVED exception (e.g. after a retry) must NOT suppress a fresh failure.
      insert into sync_exceptions (tenant_id, outbox_id, error_code, error_detail, payload_json)
      select v_row.tenant_id, v_row.id, v_code, SQLERRM, v_row.payload_json
      where not exists (select 1 from sync_exceptions e
                         where e.outbox_id = v_row.id and e.status = 'OPEN'::sync_exception_status_enum);
    end if;
    return jsonb_build_object('applied', false, 'error', v_code, 'terminal', v_terminal, 'at_cap', v_at_cap);
  end;
end; $function$;

-- B. retry_sync_intent -------------------------------------------------------------------------
create or replace function public.retry_sync_intent(p_outbox_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare v_row sync_outbox; v_claims text; v_res jsonb;
begin
  if not auth_has_permission('sync','resolve') then raise exception 'ERR_PERMISSION_DENIED'; end if;
  -- tenant-scope BEFORE any impersonation (the caller is the resolver, not the cashier)
  select * into v_row from sync_outbox where id=p_outbox_id and tenant_id=auth_tenant_id() for update;
  if not found then raise exception 'ERR_INTENT_NOT_FOUND'; end if;
  if v_row.status = 'APPLIED'::sync_intent_status_enum then
    return jsonb_build_object('retried', false, 'already_applied', true, 'invoice_id', v_row.invoice_id);
  end if;
  if v_row.status not in ('ABANDONED'::sync_intent_status_enum,'FAILED'::sync_intent_status_enum) then
    raise exception 'ERR_INTENT_NOT_RETRYABLE';   -- PENDING/REPLAYING are in-flight; leave them
  end if;

  -- close the OPEN exception(s) for this intent, stamped with WHO retried (re-fail re-surfaces via the OPEN guard)
  update sync_exceptions set status='RESOLVED'::sync_exception_status_enum,
         resolution_note='Re-queued for replay', resolved_by=auth.uid(), resolved_at=now(), updated_at=now()
   where outbox_id=v_row.id and status='OPEN'::sync_exception_status_enum and tenant_id=v_row.tenant_id;

  -- re-queue: back to PENDING, retry budget reset
  update sync_outbox set status='PENDING'::sync_intent_status_enum, attempts=0, last_error=null, updated_at=now()
   where id=v_row.id;

  -- replay NOW as the ORIGINAL cashier (correct cashier_id/attribution), like sync_drain_cron; restore claims after
  v_claims := current_setting('request.jwt.claims', true);
  perform set_config('request.jwt.claims',
    json_build_object('sub', v_row.user_id, 'role', 'authenticated')::text, true);
  v_res := public.sync_replay_sale_intent(v_row.id);
  perform set_config('request.jwt.claims', coalesce(v_claims, ''), true);

  return jsonb_build_object('retried', true, 'outbox_id', v_row.id, 'replay', v_res);
end; $function$;

-- ACL: create re-grants EXECUTE to PUBLIC by default → least-privilege (create_sale/D5 lesson)
revoke execute on function public.retry_sync_intent(uuid) from public, anon;
grant execute on function public.retry_sync_intent(uuid) to authenticated, service_role;
