-- Fix notify(): the status CASE resolved to text (two string literals), and there is no
-- implicit text -> notification_status_enum cast, so every notify() call threw 42804 and
-- inserted nothing. Cast the CASE result to the enum. Body otherwise byte-identical to the
-- notifications_dispatch definition.

create or replace function public.notify(
  p_user_id uuid,
  p_event_type varchar,
  p_title varchar,
  p_body text,
  p_priority notification_priority_enum,
  p_action_type varchar,
  p_action_id uuid,
  p_action_url varchar,
  p_vars jsonb
) returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare v_t uuid := public.auth_tenant_id(); v_channels jsonb; v_ch text; v_enabled boolean; v_n int := 0;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  -- resolve prefs (default IN_APP only if no row)
  select channels, enabled into v_channels, v_enabled from notification_preferences where user_id=p_user_id and event_type=p_event_type;
  if v_channels is null then v_channels := '["IN_APP"]'::jsonb; v_enabled := true; end if;
  if not coalesce(v_enabled,true) then return jsonb_build_object('suppressed', true); end if;

  for v_ch in select jsonb_array_elements_text(v_channels) loop
    insert into notifications (tenant_id, user_id, title, body, channel, priority, status, action_type, action_id, action_url, metadata)
    values (v_t, p_user_id, p_title, p_body, v_ch::notification_channel_enum, coalesce(p_priority,'NORMAL'),
            (case when v_ch='IN_APP' then 'DELIVERED' else 'PENDING' end)::notification_status_enum,   -- IN_APP is instant; others queued for the sender
            p_action_type, p_action_id, p_action_url, jsonb_build_object('event_type', p_event_type, 'vars', p_vars));
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('enqueued', v_n, 'channels', v_channels);
end; $$;
