-- render {{placeholders}} in a template body from a jsonb of vars
create or replace function public.render_template(p_body text, p_vars jsonb)
returns text language plpgsql immutable as $function$
declare v_out text := p_body; k text; val text;
begin
  if p_vars is null then return v_out; end if;
  for k, val in select key, value from jsonb_each_text(p_vars) loop
    v_out := replace(v_out, '{{'||k||'}}', coalesce(val,''));
  end loop;
  return v_out;
end; $function$;

-- notify(): the single entry point producers SHOULD call. Preference-aware, multi-channel enqueue.
-- Resolves the user's enabled channels for p_event_type (notification_preferences; default ['IN_APP']),
-- always writes the IN_APP row, and enqueues one PENDING row per additional enabled channel (SMS/EMAIL/PUSH/
-- WHATSAPP) that the sender (N4) will drain. Renders title/body from templates when present.
create or replace function public.notify(
  p_user_id uuid, p_event_type varchar, p_title varchar, p_body text, p_priority notification_priority_enum,
  p_action_type varchar, p_action_id uuid, p_action_url varchar, p_vars jsonb
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
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
            case when v_ch='IN_APP' then 'DELIVERED' else 'PENDING' end,   -- IN_APP is instant; others queued for the sender
            p_action_type, p_action_id, p_action_url, jsonb_build_object('event_type', p_event_type, 'vars', p_vars));
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('enqueued', v_n, 'channels', v_channels);
end; $function$;

-- read helpers (mark_notification_read exists; add these)
create or replace function public.mark_all_notifications_read()
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_n int;
begin
  update notifications set read_at=now(), status='READ' where user_id=auth.uid() and read_at is null;
  get diagnostics v_n = row_count; return jsonb_build_object('marked', v_n);
end; $function$;

create or replace function public.unread_notification_count()
returns integer language sql stable security definer set search_path to 'public' as $$
  select count(*)::int from notifications where user_id=auth.uid() and read_at is null and channel='IN_APP';
$$;

-- upsert a user's channel preference for an event type
create or replace function public.upsert_notification_preference(p_event_type varchar, p_channels jsonb, p_enabled boolean)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_id uuid;
begin
  insert into notification_preferences (user_id, event_type, channels, enabled)
  values (auth.uid(), p_event_type, coalesce(p_channels,'["IN_APP"]'), coalesce(p_enabled,true))
  on conflict (user_id, event_type) do update set channels=excluded.channels, enabled=excluded.enabled, updated_at=now()
  returning id into v_id;
  return jsonb_build_object('preference_id', v_id);
end; $function$;