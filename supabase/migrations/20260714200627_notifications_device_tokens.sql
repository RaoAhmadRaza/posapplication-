-- SCHEMA EXTENSION (sign-off): device_tokens — not in DATABASE_SCHEMA.md. Minimal FCM token store.
create table if not exists public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  user_id uuid not null references public.users(id),
  token text not null,
  platform varchar(20) not null,           -- ios/android/web
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  last_seen_at timestamptz
);
create unique index if not exists uq_device_tokens on public.device_tokens(user_id, token);
alter table public.device_tokens enable row level security;
drop policy if exists "dt own" on public.device_tokens;
create policy "dt own" on public.device_tokens for all to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());

create or replace function public.register_device_token(p_token text, p_platform varchar)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid:=public.auth_tenant_id();
begin
  insert into device_tokens (tenant_id, user_id, token, platform, last_seen_at)
  values (v_t, auth.uid(), p_token, p_platform, now())
  on conflict (user_id, token) do update set is_active=true, last_seen_at=now();
  return jsonb_build_object('ok', true);
end; $function$;