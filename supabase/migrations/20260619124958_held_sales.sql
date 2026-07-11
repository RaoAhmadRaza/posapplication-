-- <ts>_held_sales.sql  (DATABASE_SCHEMA.md §3.5 held_sales). Direct tenant-scoped CRUD (no stock/money).
create table if not exists public.held_sales (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid not null references public.branches(id),
  cashier_id uuid not null references public.users(id),
  session_id uuid references public.cashier_sessions(id),
  customer_id uuid references public.customers(id),
  cart_json jsonb not null,
  label varchar(255),
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_held_sales_branch  on public.held_sales(branch_id);
create index if not exists idx_held_sales_cashier on public.held_sales(cashier_id);
alter table public.held_sales enable row level security;
drop policy if exists held_sales_tenant on public.held_sales;
create policy held_sales_tenant on public.held_sales
  using (tenant_id = public.auth_tenant_id()) with check (tenant_id = public.auth_tenant_id());
grant select, insert, delete on public.held_sales to authenticated;