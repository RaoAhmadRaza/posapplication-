-- notify() PUSH guard — the preventive half. No device can register an FCM token (Flutter half of
-- push deferred, never built), so a PUSH row can never be delivered by construction. The disabled
-- settings-UI toggle (2026-07-16, prior fix) only stops NEW opt-ins via the app; notify() itself has
-- no channel filter and blindly inserts whatever notification_preferences.channels contains, with no
-- CHECK constraint on that column stopping 'PUSH' from arriving any other way (e.g. direct API use).
-- "No PUSH row, no problem": this is the actual fix. The sender's SKIP-not-FAIL (deployed separately,
-- not a migration) is defense-in-depth for any PUSH row that lands via a path other than notify() —
-- know which is which; don't rely on the sender alone.
--
-- Reversible in one line when device tokens ship: delete the `if v_ch = 'PUSH' ... continue;` guard.
--
-- Requires 'SKIPPED' from 20260717073356_notification_status_add_skipped.sql, applied first.
-- Byte-identical to the fresh dump except: v_skipped tracking + the PUSH branch inside the loop.
CREATE OR REPLACE FUNCTION public.notify(
  p_user_id uuid, p_event_type character varying, p_title character varying, p_body text,
  p_priority notification_priority_enum, p_action_type character varying, p_action_id uuid,
  p_action_url character varying, p_vars jsonb
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public' AS $$
declare v_t uuid := public.auth_tenant_id(); v_channels jsonb; v_ch text; v_enabled boolean; v_n int := 0;
  v_skipped jsonb := '[]'::jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  -- resolve prefs (default IN_APP only if no row)
  select channels, enabled into v_channels, v_enabled from notification_preferences where user_id=p_user_id and event_type=p_event_type;
  if v_channels is null then v_channels := '["IN_APP"]'::jsonb; v_enabled := true; end if;
  if not coalesce(v_enabled,true) then return jsonb_build_object('suppressed', true); end if;

  for v_ch in select jsonb_array_elements_text(v_channels) loop
    if v_ch = 'PUSH' then
      -- PUSH has no delivery transport (no device token registration exists). No row, no problem —
      -- counted separately so the caller can see it was suppressed, not silently dropped.
      v_skipped := v_skipped || to_jsonb('PUSH'::text);
      continue;
    end if;
    insert into notifications (tenant_id, user_id, title, body, channel, priority, status, action_type, action_id, action_url, metadata)
    values (v_t, p_user_id, p_title, p_body, v_ch::notification_channel_enum, coalesce(p_priority,'NORMAL'),
            (case when v_ch='IN_APP' then 'DELIVERED' else 'PENDING' end)::notification_status_enum,   -- IN_APP is instant; others queued for the sender
            p_action_type, p_action_id, p_action_url, jsonb_build_object('event_type', p_event_type, 'vars', p_vars));
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('enqueued', v_n, 'skipped', v_skipped, 'channels', v_channels);
end;
$$;
