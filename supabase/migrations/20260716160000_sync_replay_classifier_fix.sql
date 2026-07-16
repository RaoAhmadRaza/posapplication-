-- Sync replay classifier fix (bug class #7 — silent FAILED-at-cap).
-- Plain create-or-replace; same arg list; NOT a money RPC (it CALLS create_sale).
-- Two surgical changes to sync_replay_sale_intent's exception handler:
--   1. Terminal regex += NO_TENANT|PERMISSION_DENIED. Both are create_sale's 42501 guards; an
--      impersonating drain (a since-revoked/tenant-less cashier) hits exactly these, and neither
--      will EVER succeed on retry. Previously mis-classified transient → looped to the retry cap,
--      then sync_drain_cron's `attempts < 5` filter excluded them → stuck FAILED, invisible.
--   2. A transient failure that EXHAUSTS its retries (attempts reached the cap) will never be
--      re-drained either, so it needs a human exactly as much as a terminal one. Surface BOTH
--      terminal AND at-cap rows in the Exception Centre. Insert is guarded not-exists (no unique
--      index on sync_exceptions.outbox_id) so it stays single-row per intent.
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
    for update skip locked;                            -- skip locked: two drivers never fight over one intent
  if not found then return jsonb_build_object('skipped', true); end if;

  update sync_outbox set status='REPLAYING'::sync_intent_status_enum,   -- explicit ::enum (bug class #1)
         attempts=attempts+1, updated_at=now() where id=v_row.id;

  begin
    -- Route THROUGH the sole writer. Semantics unchanged. next_number allocates HERE, server-side, at replay.
    v_res := create_sale(v_row.branch_id, (v_row.payload_json->>'customer_id')::uuid,
                         v_row.payload_json->'items', v_row.payload_json->'payments',
                         v_row.payload_json->>'notes', (v_row.payload_json->>'session_id')::uuid,
                         v_row.idempotency_key);
    update sync_outbox set status='APPLIED'::sync_intent_status_enum,
           invoice_id=(v_res->>'invoice_id')::uuid, applied_at=now(), updated_at=now() where id=v_row.id;
    -- The FIRST writer is_offline/synced_at have ever had (live-but-vestigial since the superseded design).
    update invoices set is_offline=true, synced_at=now(), device_id=v_row.device_id, local_ref=v_row.local_ref
     where id=(v_res->>'invoice_id')::uuid;
    return jsonb_build_object('applied', true, 'invoice_id', v_res->>'invoice_id');
  exception when others then
    v_code := coalesce(nullif(SQLERRM,''),'ERR_UNKNOWN');
    -- TERMINAL vs TRANSIENT is a DECISION, not a default. These codes will NEVER succeed on retry;
    -- retrying them forever is noise that buries the real queue.
    -- NOTE: parenthesised — `~` binds tighter than `||`, so without these parens only the first fragment
    -- would be the pattern (an unbalanced `ERR_(` → "parentheses not balanced").
    v_terminal := v_code ~ ('ERR_(INSUFFICIENT_STOCK|CREDIT_LIMIT_EXCEEDED|IMEI_NOT_AVAILABLE|BELOW_MIN_PRICE|'
                        || 'PRODUCT_NOT_FOUND|IMEI_REQUIRED|SERIALIZED_QTY_ONE|INVALID_QTY|EMPTY_CART|'
                        || 'PAYMENT_NONPOSITIVE|CREDIT_REQUIRES_CUSTOMER|NO_OPEN_SESSION|BRANCH_NOT_ASSIGNED|'
                        || 'NO_TENANT|PERMISSION_DENIED)');
    -- Retry cap mirrors sync_drain_cron's `attempts < 5`: past the cap a row is never re-drained,
    -- so a transient that reached the cap is as stuck as a terminal one → surface it to a human too.
    v_at_cap := (v_row.attempts + 1) >= 5;
    update sync_outbox set status = case when v_terminal then 'ABANDONED'::sync_intent_status_enum
                                         else 'FAILED'::sync_intent_status_enum end,   -- CASE loses the cast: both arms carry ::enum
           last_error=v_code, updated_at=now() where id=v_row.id;
    if v_terminal or v_at_cap then
      insert into sync_exceptions (tenant_id, outbox_id, error_code, error_detail, payload_json)
      select v_row.tenant_id, v_row.id, v_code, SQLERRM, v_row.payload_json
      where not exists (select 1 from sync_exceptions e where e.outbox_id = v_row.id);
    end if;
    return jsonb_build_object('applied', false, 'error', v_code, 'terminal', v_terminal, 'at_cap', v_at_cap);
  end;
end; $function$;
