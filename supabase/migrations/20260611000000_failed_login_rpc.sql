-- 20260611000000_failed_login_rpc.sql
-- Server-side brute-force counter. Complements the local secure-storage throttle
-- in login_throttle_service.dart. Called on every failed login and on successful
-- login (reset). Applies on top of 20260609000002_auth_full_schema.sql which
-- added failed_login_count / locked_until columns on public.users.

create or replace function public.increment_failed_login(p_email text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_user_id uuid;
  v_count integer;
  v_locked_until timestamptz;
begin
  select id, failed_login_count, locked_until
  into v_user_id, v_count, v_locked_until
  from public.users
  where email = p_email;

  if not found then
    return jsonb_build_object('found', false);
  end if;

  if v_locked_until is not null and v_locked_until > now() then
    return jsonb_build_object(
      'found', true,
      'locked', true,
      'locked_until', v_locked_until
    );
  end if;

  v_count := coalesce(v_count, 0) + 1;

  if v_count >= 5 then
    v_locked_until := now() + interval '15 minutes';
  else
    v_locked_until := null;
  end if;

  update public.users
  set failed_login_count = v_count,
      locked_until = v_locked_until
  where id = v_user_id;

  return jsonb_build_object(
    'found', true,
    'locked', v_locked_until is not null,
    'failed_login_count', v_count,
    'locked_until', v_locked_until
  );
end;
$$;

grant execute on function public.increment_failed_login(text) to authenticated;

create or replace function public.reset_failed_login(p_email text)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  update public.users
  set failed_login_count = 0,
      locked_until = null
  where email = p_email;
end;
$$;

grant execute on function public.reset_failed_login(text) to authenticated;
