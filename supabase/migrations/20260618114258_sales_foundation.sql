-- <timestamp>_sales_foundation.sql
-- Sales module foundation: customers, cashier_sessions, invoices, invoice_items, payments;
-- RLS; INVOICE number_series seed; sales permission backfill; open/close session + create_sale RPCs;
-- invoice immutability trigger. Idempotent + additive. Reconciled to DATABASE_SCHEMA.md §2, §3.5, §3.8, §9.

-- ========== 0. PATCH post_stock_movement: operation-aware permission gate ==========
-- WHY: the engine gates ALL movements on inventory:update, but CASHIER has only inventory:read.
-- A sale's stock decrement must run for cashiers. SECURITY DEFINER does NOT change auth.uid(), so the
-- inner gate still reads the caller's perms. Fix: SALE/RETURN_IN/RETURN_OUT accept sales perms; everything
-- else stays inventory:update. This keeps the SINGLE write path (no direct ledger inserts).
--
-- ⚠ ACTION: CREATE OR REPLACE needs the FULL current body. Open
--   supabase/migrations/20260613061924_stock_engine.sql (the post_stock_movement function, ~lines 209-262),
--   paste its body here UNCHANGED, and replace ONLY its permission-gate block with the block below. Do not
--   alter any other line (tenant/branch/product validation, ledger insert, return).
--
-- Replace the existing gate (currently approx:
--     if not public.auth_has_permission('inventory','update') then
--       raise exception 'permission denied' using errcode='42501'; end if; )
-- with:
--     if p_operation_type in ('SALE','RETURN_IN','RETURN_OUT') then
--       if not (public.auth_has_permission('sales','create') or public.auth_has_permission('sales','update')) then
--         raise exception 'permission denied' using errcode='42501';
--       end if;
--     else
--       if not public.auth_has_permission('inventory','update') then
--         raise exception 'permission denied' using errcode='42501';
--       end if;
--     end if;
--
-- (If you prefer not to touch the engine in this migration: the only alternative that works for cashiers is
--  granting CASHIER inventory:update — REJECTED here because that also unlocks direct product/stock edits in
--  the inventory UI. The operation-aware gate is the correct, narrow fix.)

-- ========== 1. ENUMS (guarded — skip if already present) ==========
do $$ begin
  if not exists (select 1 from pg_type where typname='customer_status_enum') then
    create type customer_status_enum as enum ('ACTIVE','INACTIVE','BLACKLISTED');
  end if;
  if not exists (select 1 from pg_type where typname='invoice_status_enum') then
    create type invoice_status_enum as enum ('DRAFT','CONFIRMED','PARTIALLY_PAID','PAID','RETURNED','VOID');
  end if;
  if not exists (select 1 from pg_type where typname='sale_type_enum') then
    create type sale_type_enum as enum ('CASH','CREDIT','MIXED');
  end if;
  if not exists (select 1 from pg_type where typname='payment_method_enum') then
    create type payment_method_enum as enum ('CASH','BANK_TRANSFER','CARD','MOBILE_WALLET','CHEQUE','LOYALTY_POINTS','CREDIT_NOTE');
  end if;
  if not exists (select 1 from pg_type where typname='cashier_session_status_enum') then
    create type cashier_session_status_enum as enum ('OPEN','CLOSED','SUSPENDED');
  end if;
end $$;

-- ========== 2. CUSTOMERS (DATABASE_SCHEMA.md §3.8) ==========
create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name varchar(255) not null,
  phone varchar(50), phone_secondary varchar(50), email varchar(255),
  address_line1 varchar(255), address_line2 varchar(255),
  city varchar(100), state varchar(100), postal_code varchar(20), country varchar(100) default 'Pakistan',
  tax_number varchar(50), group_id uuid,
  credit_limit decimal(15,4) not null default 0,
  credit_terms integer not null default 0,
  loyalty_points integer not null default 0,
  opening_balance decimal(15,4) not null default 0,
  status customer_status_enum not null default 'ACTIVE',
  tags text[], custom_fields_json jsonb default '{}'::jsonb, notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  deleted_at timestamptz, version integer not null default 1,
  created_by uuid references public.users(id), updated_by uuid references public.users(id)
);
create index if not exists idx_customers_tenant_phone on public.customers(tenant_id, phone) where deleted_at is null;
create index if not exists idx_customers_tenant_name  on public.customers(tenant_id, name)  where deleted_at is null;
create index if not exists idx_customers_status        on public.customers(tenant_id, status) where deleted_at is null;

-- ========== 3. CASHIER SESSIONS (DATABASE_SCHEMA.md §3.5) ==========
create table if not exists public.cashier_sessions (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid not null references public.branches(id),
  cashier_id uuid not null references public.users(id),
  device_id uuid,
  opening_float decimal(15,4) not null default 0,
  closing_float decimal(15,4),
  expected_float decimal(15,4),
  cash_variance decimal(15,4),
  total_sales decimal(15,4) not null default 0,
  total_returns decimal(15,4) not null default 0,
  total_transactions integer not null default 0,
  status cashier_session_status_enum not null default 'OPEN',
  opened_at timestamptz not null default now(),
  closed_at timestamptz, closed_by uuid references public.users(id), notes text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  version integer not null default 1
);
create index if not exists idx_cashier_sessions_branch on public.cashier_sessions(branch_id, status);
create index if not exists idx_cashier_sessions_cashier on public.cashier_sessions(cashier_id, opened_at);
-- one OPEN session per cashier+branch
create unique index if not exists uq_cashier_session_open
  on public.cashier_sessions(tenant_id, branch_id, cashier_id) where status = 'OPEN';

-- ========== 4. INVOICES (DATABASE_SCHEMA.md §3.5) ==========
create table if not exists public.invoices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid not null references public.branches(id),
  invoice_number varchar(50) not null,
  customer_id uuid references public.customers(id),
  cashier_id uuid not null references public.users(id),
  session_id uuid references public.cashier_sessions(id),
  status invoice_status_enum not null default 'DRAFT',
  sale_type sale_type_enum not null default 'CASH',
  subtotal decimal(15,4) not null default 0,
  discount_total decimal(15,4) not null default 0,
  tax_total decimal(15,4) not null default 0,
  grand_total decimal(15,4) not null default 0,
  paid_amount decimal(15,4) not null default 0,
  balance decimal(15,4) not null default 0,
  change_amount decimal(15,4) not null default 0,
  notes text, return_reason text,
  original_invoice_id uuid references public.invoices(id),
  correlation_id uuid, is_offline boolean not null default false, synced_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  deleted_at timestamptz, version integer not null default 1,
  created_by uuid references public.users(id), updated_by uuid references public.users(id)
);
create unique index if not exists uq_invoices_tenant_number on public.invoices(tenant_id, invoice_number) where deleted_at is null;
create index if not exists idx_invoices_branch_created on public.invoices(branch_id, created_at) where deleted_at is null;
create index if not exists idx_invoices_customer on public.invoices(customer_id) where deleted_at is null and customer_id is not null;
create index if not exists idx_invoices_status on public.invoices(tenant_id, status) where deleted_at is null;
create index if not exists idx_invoices_cashier on public.invoices(cashier_id, created_at) where deleted_at is null;
create index if not exists idx_invoices_session on public.invoices(session_id) where deleted_at is null;
create index if not exists idx_invoices_tenant_created on public.invoices(tenant_id, created_at) where deleted_at is null;

-- ========== 5. INVOICE ITEMS (DATABASE_SCHEMA.md §3.5) ==========
create table if not exists public.invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.invoices(id) on delete cascade,
  product_id uuid not null references public.products(id),
  variant_id uuid, imei_id uuid references public.imei_records(id),
  description varchar(500),
  qty decimal(15,4) not null default 1,
  unit_price decimal(15,4) not null,
  cost_price decimal(15,4) not null,
  discount_pct decimal(5,2) not null default 0,
  discount_amount decimal(15,4) not null default 0,
  tax_pct decimal(5,2) not null default 0,
  tax_amount decimal(15,4) not null default 0,
  line_total decimal(15,4) not null,
  profit decimal(15,4) not null default 0,
  pricing_tier varchar(100),
  created_at timestamptz not null default now()
);
create index if not exists idx_invoice_items_invoice on public.invoice_items(invoice_id);
create index if not exists idx_invoice_items_product on public.invoice_items(product_id);
create index if not exists idx_invoice_items_imei on public.invoice_items(imei_id) where imei_id is not null;

-- ========== 6. PAYMENTS (DATABASE_SCHEMA.md §3.5) ==========
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  invoice_id uuid not null references public.invoices(id),
  method payment_method_enum not null,
  amount decimal(15,4) not null,
  reference varchar(255), bank_account_id uuid, device_id uuid,
  correlation_id uuid, notes text,
  created_at timestamptz not null default now(), created_by uuid references public.users(id),
  constraint chk_payments_amount_positive check (amount > 0)
);
create index if not exists idx_payments_invoice on public.payments(invoice_id);
create index if not exists idx_payments_tenant_created on public.payments(tenant_id, created_at);
create index if not exists idx_payments_method on public.payments(tenant_id, method);

-- ========== 7. RLS (tenant isolation; mirror existing inventory policy pattern) ==========
alter table public.customers        enable row level security;
alter table public.cashier_sessions enable row level security;
alter table public.invoices         enable row level security;
alter table public.invoice_items    enable row level security;
alter table public.payments         enable row level security;

drop policy if exists customers_tenant on public.customers;
create policy customers_tenant on public.customers
  using (tenant_id = public.auth_tenant_id()) with check (tenant_id = public.auth_tenant_id());

drop policy if exists sessions_tenant_sel on public.cashier_sessions;
create policy sessions_tenant_sel on public.cashier_sessions for select
  using (tenant_id = public.auth_tenant_id());

drop policy if exists invoices_tenant_sel on public.invoices;
create policy invoices_tenant_sel on public.invoices for select
  using (tenant_id = public.auth_tenant_id() and deleted_at is null);

drop policy if exists invoice_items_tenant_sel on public.invoice_items;
create policy invoice_items_tenant_sel on public.invoice_items for select
  using (exists (select 1 from public.invoices i
                 where i.id = invoice_items.invoice_id and i.tenant_id = public.auth_tenant_id()));

drop policy if exists payments_tenant_sel on public.payments;
create policy payments_tenant_sel on public.payments for select
  using (tenant_id = public.auth_tenant_id());

-- write path = RPCs only (SECURITY DEFINER owner bypasses these revokes)
revoke insert, update, delete on public.invoices         from authenticated;
revoke insert, update, delete on public.invoice_items    from authenticated;
revoke insert, update, delete on public.payments         from authenticated;
revoke insert, update, delete on public.cashier_sessions from authenticated;
grant select on public.invoices, public.invoice_items, public.payments, public.cashier_sessions to authenticated;
-- customers: direct tenant-scoped CRUD allowed (CreateCustomer use case)
grant select, insert, update on public.customers to authenticated;

-- ========== 8. INVOICE IMMUTABILITY TRIGGER (DATABASE_SCHEMA.md §9.8) ==========
create or replace function public.fn_invoice_immutability()
returns trigger language plpgsql as $$
begin
  if old.status in ('PAID','RETURNED','VOID') then
    if new.status <> old.status and new.status in ('RETURNED','VOID') then
      return new;  -- allowed transitions for returns/void
    end if;
    raise exception 'ERR_INVOICE_IMMUTABLE: cannot modify invoice with status %', old.status
      using errcode='restrict_violation';
  end if;
  return new;
end; $$;
drop trigger if exists trg_invoice_immutability on public.invoices;
create trigger trg_invoice_immutability before update on public.invoices
  for each row execute function public.fn_invoice_immutability();

-- ========== 9. NUMBER SERIES SEED (INVOICE) ==========
-- Sales permissions are NOT seeded here — S0-D2/D4 confirm ADMIN(all 6) + CASHIER(read+create) already exist
-- in both the seed and handle_new_user. Returns gate on sales:update, void on sales:delete (existing actions).
-- INVOICE series per tenant (guarded; branch_id NULL matches the existing TRF-/CNT- pattern; nulls are distinct
-- in the unique index, so use NOT EXISTS). next_number('INVOICE',branch) auto-creates on miss, but with an empty
-- prefix — pre-seeding here gives the 'INV-' prefix so numbers read BR01-INV-000001.
insert into public.number_series (tenant_id, branch_id, type, prefix, suffix, current_number, padding, include_branch_code)
select t.id, null, 'INVOICE'::number_series_type_enum, 'INV-', '', 0, 6, true
from public.tenants t
where not exists (select 1 from public.number_series ns where ns.tenant_id = t.id and ns.type='INVOICE');

-- ========== 10. RPC: open_cashier_session ==========
create or replace function public.open_cashier_session(p_branch_id uuid, p_opening_float numeric default 0)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid(); v_id uuid;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('sales','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not public.auth_has_branch(p_branch_id) then raise exception 'ERR_BRANCH_NOT_ASSIGNED' using errcode='42501'; end if;
  if exists (select 1 from cashier_sessions where tenant_id=v_t and branch_id=p_branch_id and cashier_id=v_uid and status='OPEN') then
    raise exception 'ERR_SESSION_ALREADY_OPEN';
  end if;
  insert into cashier_sessions (tenant_id, branch_id, cashier_id, opening_float, status)
  values (v_t, p_branch_id, v_uid, coalesce(p_opening_float,0), 'OPEN') returning id into v_id;
  return jsonb_build_object('session_id', v_id, 'opened_at', now());
end; $$;

-- ========== 11. RPC: close_cashier_session ==========
create or replace function public.close_cashier_session(p_session_id uuid, p_closing_float numeric, p_notes text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
        v_open numeric; v_cash numeric; v_sales numeric; v_txns int; v_expected numeric; v_var numeric;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  select opening_float into v_open from cashier_sessions
    where id=p_session_id and tenant_id=v_t and status='OPEN';
  if not found then raise exception 'ERR_SESSION_NOT_OPEN'; end if;
  select coalesce(sum(p.amount),0) into v_cash from payments p
    join invoices i on i.id=p.invoice_id where i.session_id=p_session_id and p.method='CASH';
  select coalesce(sum(i.grand_total),0), count(*) into v_sales, v_txns from invoices i where i.session_id=p_session_id;
  v_expected := v_open + v_cash;
  v_var := coalesce(p_closing_float,0) - v_expected;
  update cashier_sessions
    set closing_float=coalesce(p_closing_float,0), expected_float=v_expected, cash_variance=v_var,
        total_sales=v_sales, total_transactions=v_txns, status='CLOSED', closed_at=now(), closed_by=v_uid,
        notes=coalesce(p_notes,notes), updated_at=now(), version=version+1
    where id=p_session_id;
  return jsonb_build_object('expected_float',v_expected,'closing_float',coalesce(p_closing_float,0),
    'cash_variance',v_var,'total_sales',v_sales,'total_transactions',v_txns);
end; $$;

-- ========== 12. RPC: create_sale (the heart) ==========
create or replace function public.create_sale(
  p_branch_id uuid,
  p_customer_id uuid,
  p_items jsonb,      -- [{product_id, qty, unit_price, discount_pct?, tax_pct?, imei_id?, variant_id?, description?}]
  p_payments jsonb,   -- [{method, amount, reference?, bank_account_id?}]
  p_notes text default null,
  p_session_id uuid default null
) returns jsonb language plpgsql security definer set search_path = public as $$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid(); v_session uuid;
  v_invoice uuid := gen_random_uuid(); v_number varchar; r jsonb;
  v_pid uuid; v_qty numeric; v_unit numeric; v_dp numeric; v_tp numeric; v_imei uuid; v_variant uuid; v_desc text;
  v_ptype product_type_enum; v_cost numeric; v_da numeric; v_taxable numeric; v_ta numeric; v_line numeric; v_profit numeric;
  v_subtotal numeric:=0; v_disc numeric:=0; v_tax numeric:=0; v_grand numeric:=0;
  v_paid numeric:=0; v_change numeric; v_applied numeric; v_balance numeric; v_methods int:=0;
  v_status invoice_status_enum; v_sale_type sale_type_enum;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('sales','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not public.auth_has_branch(p_branch_id) then raise exception 'ERR_BRANCH_NOT_ASSIGNED' using errcode='42501'; end if;
  if p_items is null or jsonb_array_length(p_items)=0 then raise exception 'ERR_EMPTY_CART'; end if;

  -- resolve OPEN session
  if p_session_id is not null then
    select id into v_session from cashier_sessions where id=p_session_id and tenant_id=v_t and status='OPEN';
  else
    select id into v_session from cashier_sessions
      where tenant_id=v_t and branch_id=p_branch_id and cashier_id=v_uid and status='OPEN'
      order by opened_at desc limit 1;
  end if;
  if v_session is null then raise exception 'ERR_NO_OPEN_SESSION'; end if;

  -- invoice number  (S0-C1: next_number(type, branch) — type FIRST, NO tenant arg)
  v_number := public.next_number('INVOICE'::number_series_type_enum, p_branch_id);

  -- header (zeros; filled after items). status DRAFT so the immutability trigger allows the later UPDATE.
  insert into invoices (id, tenant_id, branch_id, invoice_number, customer_id, cashier_id, session_id,
                        status, sale_type, notes, created_by, updated_by)
  values (v_invoice, v_t, p_branch_id, v_number, p_customer_id, v_uid, v_session, 'DRAFT', 'CASH', p_notes, v_uid, v_uid);

  -- items
  for r in select * from jsonb_array_elements(p_items) loop
    v_pid := (r->>'product_id')::uuid;
    v_qty := coalesce((r->>'qty')::numeric, 1);
    v_unit := coalesce((r->>'unit_price')::numeric, 0);
    v_dp := coalesce((r->>'discount_pct')::numeric, 0);
    v_tp := coalesce((r->>'tax_pct')::numeric, 0);
    v_imei := nullif(r->>'imei_id','')::uuid;
    v_variant := nullif(r->>'variant_id','')::uuid;
    v_desc := nullif(r->>'description','');
    if v_qty <= 0 then raise exception 'ERR_INVALID_QTY'; end if;

    select type into v_ptype from products where id=v_pid and tenant_id=v_t and deleted_at is null;
    if not found then raise exception 'ERR_PRODUCT_NOT_FOUND: %', v_pid; end if;
    if v_ptype='SERIALIZED' then
      if v_imei is null then raise exception 'ERR_IMEI_REQUIRED: %', v_pid; end if;
      if v_qty <> 1 then raise exception 'ERR_SERIALIZED_QTY_ONE: %', v_pid; end if;
    end if;

    select coalesce(avg_cost,0) into v_cost from stock_balance
      where tenant_id=v_t and branch_id=p_branch_id and product_id=v_pid and warehouse_id is null;
    v_cost := coalesce(v_cost,0);

    v_da := round(v_qty*v_unit*v_dp/100.0, 4);
    v_taxable := v_qty*v_unit - v_da;
    v_ta := round(v_taxable*v_tp/100.0, 4);
    v_line := v_taxable + v_ta;
    v_profit := (v_unit - v_cost)*v_qty - v_da;

    insert into invoice_items (invoice_id, product_id, variant_id, imei_id, description, qty, unit_price,
                              cost_price, discount_pct, discount_amount, tax_pct, tax_amount, line_total, profit)
    values (v_invoice, v_pid, v_variant, v_imei, v_desc, v_qty, v_unit,
            v_cost, v_dp, v_da, v_tp, v_ta, v_line, v_profit);

    v_subtotal := v_subtotal + v_qty*v_unit;
    v_disc := v_disc + v_da; v_tax := v_tax + v_ta; v_grand := v_grand + v_line;
  end loop;

  -- payments
  if p_payments is not null then
    for r in select * from jsonb_array_elements(p_payments) loop
      if coalesce((r->>'amount')::numeric,0) <= 0 then raise exception 'ERR_PAYMENT_NONPOSITIVE'; end if;
      insert into payments (tenant_id, invoice_id, method, amount, reference, bank_account_id, created_by)
      values (v_t, v_invoice, (r->>'method')::payment_method_enum, (r->>'amount')::numeric,
              nullif(r->>'reference',''), nullif(r->>'bank_account_id','')::uuid, v_uid);
      v_paid := v_paid + (r->>'amount')::numeric;
    end loop;
    select count(distinct e->>'method') into v_methods from jsonb_array_elements(p_payments) e;
  end if;

  v_change := greatest(v_paid - v_grand, 0);
  v_applied := least(v_paid, v_grand);
  v_balance := v_grand - v_applied;
  if v_balance <= 0 then v_status := 'PAID';
  elsif v_applied > 0 then v_status := 'PARTIALLY_PAID';
  else v_status := 'CONFIRMED'; end if;

  if v_balance > 0 then
    if p_customer_id is null then raise exception 'ERR_CREDIT_REQUIRES_CUSTOMER'; end if;
    v_sale_type := 'CREDIT';
  elsif v_methods > 1 then v_sale_type := 'MIXED';
  else v_sale_type := 'CASH'; end if;

  update invoices set subtotal=v_subtotal, discount_total=v_disc, tax_total=v_tax, grand_total=v_grand,
    paid_amount=v_applied, balance=v_balance, change_amount=v_change, status=v_status, sale_type=v_sale_type,
    updated_at=now(), updated_by=v_uid
  where id=v_invoice;

  -- stock decrement (atomic; P0001 rolls everything back).
  -- S0-B1: post_stock_movement ARG4 = p_variant_id (NOT imei). Pass v_variant (null for standard products).
  -- S0-B2: the engine does NOT touch imei_records — we update it separately below (sold_invoice_id + SOLD).
  for r in select * from jsonb_array_elements(p_items) loop
    v_pid := (r->>'product_id')::uuid;
    v_qty := coalesce((r->>'qty')::numeric, 1);
    v_variant := nullif(r->>'variant_id','')::uuid;
    v_imei := nullif(r->>'imei_id','')::uuid;
    select coalesce(avg_cost,0) into v_cost from stock_balance
      where tenant_id=v_t and branch_id=p_branch_id and product_id=v_pid and warehouse_id is null;
    begin
      perform public.post_stock_movement(
        p_branch_id, null, v_pid, v_variant, 'SALE', -v_qty, coalesce(v_cost,0), 'SALE', v_invoice, 'pos sale');
    exception when sqlstate 'P0001' then
      raise exception 'ERR_INSUFFICIENT_STOCK: %', v_pid using errcode='P0001';
    end;
    -- IMEI link (engine doesn't do this). imei_records.sold_invoice_id was added in Slice C for this.
    if v_imei is not null then
      update imei_records set status='SOLD', sold_invoice_id=v_invoice
        where id=v_imei and tenant_id=v_t and status='AVAILABLE';
      if not found then raise exception 'ERR_IMEI_NOT_AVAILABLE: %', v_imei; end if;
    end if;
  end loop;

  return jsonb_build_object('invoice_id',v_invoice,'invoice_number',v_number,'grand_total',v_grand,
    'paid_amount',v_applied,'balance',v_balance,'change_amount',v_change,'status',v_status);
end; $$;

-- ========== 13. GRANTS ==========
revoke all on function public.open_cashier_session(uuid,numeric)  from anon, public;
revoke all on function public.close_cashier_session(uuid,numeric,text) from anon, public;
revoke all on function public.create_sale(uuid,uuid,jsonb,jsonb,text,uuid) from anon, public;
grant execute on function public.open_cashier_session(uuid,numeric)  to authenticated;
grant execute on function public.close_cashier_session(uuid,numeric,text) to authenticated;
grant execute on function public.create_sale(uuid,uuid,jsonb,jsonb,text,uuid) to authenticated;