-- Tenant (the store)
create table if not exists public.tenants (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

-- Roles
create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid references public.tenants(id),
  name text not null,
  created_at timestamptz not null default now()
);

-- App users / profiles, linked 1:1 to Supabase auth.users
create table if not exists public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  tenant_id uuid references public.tenants(id),
  role_id uuid references public.roles(id),
  full_name text,
  email text,
  status text not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Seed one store + two roles (fixed IDs so the trigger can reference them)
insert into public.tenants (id, name)
values ('00000000-0000-0000-0000-000000000001', 'Demo Store')
on conflict (id) do nothing;

insert into public.roles (id, tenant_id, name) values
  ('00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000001','ADMIN'),
  ('00000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000001','CASHIER')
on conflict (id) do nothing;

-- Auto-create a profile row on every new signup (initial version)
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.users (id, tenant_id, role_id, email, full_name)
  values (
    new.id,
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000012',
    new.email,
    coalesce(new.raw_user_meta_data->>'full_name', '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Minimal RLS
alter table public.users enable row level security;
drop policy if exists "users read own" on public.users;
create policy "users read own"  on public.users for select using (auth.uid() = id);
drop policy if exists "users update own" on public.users;
create policy "users update own" on public.users for update using (auth.uid() = id);

alter table public.roles enable row level security;
drop policy if exists "roles read" on public.roles;
create policy "roles read" on public.roles for select to authenticated using (true);

alter table public.tenants enable row level security;
drop policy if exists "tenants read" on public.tenants;
create policy "tenants read" on public.tenants for select to authenticated using (true);
