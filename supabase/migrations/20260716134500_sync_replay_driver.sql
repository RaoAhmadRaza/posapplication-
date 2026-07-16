-- ===== Immutability relaxation for the offline stamp (reconciled to the LIVE fn_invoice_immutability body). =====
-- create_sale finalizes the invoice to PAID; the replay driver then stamps is_offline/synced_at/device_id/local_ref
-- (D3 columns, D3's idx_invoices_offline exists precisely for this). The existing trigger blocks ALL updates to a
-- PAID/RETURNED/VOID invoice, so the stamp was rejected with ERR_INVOICE_IMMUTABLE. We permit a METADATA-ONLY stamp:
-- the update is allowed on a finalized invoice ONLY when status is unchanged AND every column except the four sync
-- columns (+ updated_at/updated_by) is byte-identical — a jsonb diff, so no financial field can slip through.
create or replace function public.fn_invoice_immutability()
returns trigger language plpgsql as $imm$
begin
  if old.status in ('PAID','RETURNED','VOID') then
    if new.status <> old.status and new.status in ('RETURNED','VOID') then
      return new;  -- allowed transitions for returns/void
    end if;
    -- offline-sync metadata stamp: financials untouched, only sync/audit columns differ
    if new.status = old.status
       and (to_jsonb(new) - array['is_offline','synced_at','device_id','local_ref','updated_at','updated_by'])
         = (to_jsonb(old) - array['is_offline','synced_at','device_id','local_ref','updated_at','updated_by']) then
      return new;
    end if;
    raise exception 'ERR_INVOICE_IMMUTABLE: cannot modify invoice with status %', old.status
      using errcode='restrict_violation';
  end if;
  return new;
end; $imm$;

create or replace function public.sync_replay_sale_intent(p_outbox_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare v_row sync_outbox; v_res jsonb; v_code text; v_terminal boolean;
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
    -- TERMINAL vs TRANSIENT is a DECISION, not a default. ERR_INSUFFICIENT_STOCK will NEVER succeed on retry;
    -- retrying it forever is noise that buries the real queue.
    -- NOTE: parenthesised — `~` binds tighter than `||`, so without these parens only the first fragment
    -- would be the pattern (an unbalanced `ERR_(` → "parentheses not balanced").
    v_terminal := v_code ~ ('ERR_(INSUFFICIENT_STOCK|CREDIT_LIMIT_EXCEEDED|IMEI_NOT_AVAILABLE|BELOW_MIN_PRICE|'
                        || 'PRODUCT_NOT_FOUND|IMEI_REQUIRED|SERIALIZED_QTY_ONE|INVALID_QTY|EMPTY_CART|'
                        || 'PAYMENT_NONPOSITIVE|CREDIT_REQUIRES_CUSTOMER|NO_OPEN_SESSION|BRANCH_NOT_ASSIGNED)');
    update sync_outbox set status = case when v_terminal then 'ABANDONED'::sync_intent_status_enum
                                         else 'FAILED'::sync_intent_status_enum end,   -- CASE loses the cast: both arms carry ::enum
           last_error=v_code, updated_at=now() where id=v_row.id;
    if v_terminal then
      insert into sync_exceptions (tenant_id, outbox_id, error_code, error_detail, payload_json)
      values (v_row.tenant_id, v_row.id, v_code, SQLERRM, v_row.payload_json);
    end if;
    return jsonb_build_object('applied', false, 'error', v_code, 'terminal', v_terminal);
  end;
end; $$;

create or replace function public.resolve_sync_exception(p_id uuid, p_note text)
returns jsonb language plpgsql security definer set search_path to 'public' as $$
begin
  if not auth_has_permission('sync','resolve') then raise exception 'ERR_PERMISSION_DENIED'; end if;
  update sync_exceptions set status='RESOLVED'::sync_exception_status_enum, resolution_note=p_note,
         resolved_by=auth.uid(), resolved_at=now(), updated_at=now()
   where id=p_id and tenant_id=auth_tenant_id();
  return jsonb_build_object('resolved', true);
end; $$;

-- ACL hardening (mirrors the create_sale lesson): `create function` re-grants EXECUTE to PUBLIC by default.
-- These are SECURITY DEFINER — an anon caller could burn attempts on queued intents. Least-privilege only.
revoke execute on function public.sync_replay_sale_intent(uuid) from public, anon;
revoke execute on function public.resolve_sync_exception(uuid, text) from public, anon;
grant execute on function public.sync_replay_sale_intent(uuid) to authenticated, service_role;
grant execute on function public.resolve_sync_exception(uuid, text) to authenticated, service_role;
