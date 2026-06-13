-- <timestamp>_stock_engine.sql  (Slice B — Stock Engine)
-- Matches DATABASE_SCHEMA.md §3.7 + warehouses. Supabase RLS (auth_tenant_id/auth_has_permission)
-- supersedes the schema doc's SET LOCAL pattern. Negative stock BLOCKED. Balance maintained by trigger
-- on stock_ledger INSERT (spec business rule). Ledger immutable. Additive + idempotent.

-- ===== enums (verbatim from schema doc) =====
do $$ begin
  create type stock_movement_type_enum as enum
    ('SALE','PURCHASE_RECEIPT','RETURN_IN','RETURN_OUT','TRANSFER_OUT','TRANSFER_IN',
     'ADJUSTMENT','SCRAP','OPENING_BALANCE');
  exception when duplicate_object then null;
end $$;

-- ===== branch-isolation RLS helper =====
-- true if the signed-in user is assigned to the given branch (or it is null/their default).
create or replace function public.auth_has_branch(p_branch_id uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select p_branch_id is null
      or exists (select 1 from public.user_branch_assignments uba
                 where uba.user_id = auth.uid() and uba.branch_id = p_branch_id);
$$;

-- ===== warehouses (schema doc: belongs to a branch) =====
create table if not exists public.warehouses (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references public.tenants(id),
  branch_id      uuid not null references public.branches(id),
  name           varchar(255) not null,
  code           varchar(20)  not null,
  address        text,
  capacity_notes text,
  is_active      boolean not null default true,
  is_default     boolean not null default false,  -- default warehouse FOR THE BRANCH
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  deleted_at     timestamptz,
  version        integer not null default 1,
  created_by     uuid references public.users(id),
  updated_by     uuid references public.users(id)
);
create unique index if not exists uq_warehouses_tenant_code on public.warehouses(tenant_id, code) where deleted_at is null;
create index        if not exists idx_warehouses_branch     on public.warehouses(branch_id)        where deleted_at is null;
-- at most one default warehouse per branch
create unique index if not exists uq_warehouses_one_default_per_branch on public.warehouses(branch_id) where is_default and deleted_at is null;

-- ===== stock_ledger — IMMUTABLE (schema doc verbatim columns) =====
create table if not exists public.stock_ledger (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references public.tenants(id),
  product_id     uuid not null references public.products(id),
  variant_id     uuid references public.product_variants(id),
  branch_id      uuid not null references public.branches(id),
  warehouse_id   uuid references public.warehouses(id),
  operation_type stock_movement_type_enum not null,
  qty_change     decimal(15,4) not null,            -- + increase / - decrease
  cost_per_unit  decimal(15,4) not null default 0,
  total_cost     decimal(15,4) not null default 0,  -- qty_change * cost_per_unit
  balance_after  decimal(15,4) not null,            -- running on-hand after this movement
  avg_cost_after decimal(15,4) not null default 0,
  reference_id   uuid not null,
  reference_type varchar(50) not null,              -- INVOICE, GRN, TRANSFER, ADJUSTMENT, COUNT, OPENING
  imei_id        uuid,                              -- FK added in Slice C with imei_records
  batch_number   varchar(100),
  correlation_id uuid,
  notes          text,
  created_at     timestamptz not null default now(),
  created_by     uuid references public.users(id)
);
create index if not exists idx_stock_ledger_product_branch on public.stock_ledger(product_id, branch_id, created_at);
create index if not exists idx_stock_ledger_tenant_created on public.stock_ledger(tenant_id, created_at);
create index if not exists idx_stock_ledger_reference      on public.stock_ledger(reference_type, reference_id);
create index if not exists idx_stock_ledger_operation      on public.stock_ledger(tenant_id, operation_type, created_at);

-- ===== stock_balance — materialized projection (schema doc verbatim columns) =====
create table if not exists public.stock_balance (
  id             uuid primary key default gen_random_uuid(),
  tenant_id      uuid not null references public.tenants(id),
  branch_id      uuid not null references public.branches(id),
  warehouse_id   uuid references public.warehouses(id),   -- NULL = branch default location
  product_id     uuid not null references public.products(id),
  variant_id     uuid references public.product_variants(id),
  qty_on_hand    decimal(15,4) not null default 0,
  qty_reserved   decimal(15,4) not null default 0,
  qty_in_transit decimal(15,4) not null default 0,
  avg_cost       decimal(15,4) not null default 0,
  last_stock_take timestamptz,
  reorder_point  integer,
  last_updated   timestamptz not null default now(),
  version        integer not null default 1
);
-- spec's split uniqueness: warehouse null vs not null
create unique index if not exists uq_stock_balance_tenant_branch_product
  on public.stock_balance(tenant_id, branch_id, product_id, coalesce(variant_id,'00000000-0000-0000-0000-000000000000'::uuid))
  where warehouse_id is null;
create unique index if not exists uq_stock_balance_tenant_branch_wh_product
  on public.stock_balance(tenant_id, branch_id, warehouse_id, product_id, coalesce(variant_id,'00000000-0000-0000-0000-000000000000'::uuid))
  where warehouse_id is not null;
create index if not exists idx_stock_balance_product   on public.stock_balance(product_id);
create index if not exists idx_stock_balance_branch    on public.stock_balance(branch_id);
create index if not exists idx_stock_balance_low_stock on public.stock_balance(tenant_id, branch_id) where qty_on_hand <= 0;

-- spec CHECKs + the added on-hand guard (FIX #3: block negative)
alter table public.stock_balance drop constraint if exists chk_stock_balance_reserved;
alter table public.stock_balance add  constraint chk_stock_balance_reserved check (qty_reserved >= 0);
alter table public.stock_balance drop constraint if exists chk_stock_balance_transit;
alter table public.stock_balance add  constraint chk_stock_balance_transit  check (qty_in_transit >= 0);
alter table public.stock_balance drop constraint if exists chk_stock_balance_on_hand;
alter table public.stock_balance add  constraint chk_stock_balance_on_hand  check (qty_on_hand >= 0);

-- ===== warehouses touch trigger (reuse fn_touch_row) =====
drop trigger if exists trg_warehouses_touch on public.warehouses;
create trigger trg_warehouses_touch before update on public.warehouses for each row execute function public.fn_touch_row();

-- ===== TRIGGER: stock_ledger immutability (append-only) =====
create or replace function public.fn_stock_ledger_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'stock_ledger is immutable (append-only); compensate with a new movement'
    using errcode = 'P0001';
end; $$;
drop trigger if exists trg_stock_ledger_immutable on public.stock_ledger;
create trigger trg_stock_ledger_immutable
  before update or delete on public.stock_ledger
  for each row execute function public.fn_stock_ledger_immutable();

-- ===== TRIGGER: maintain stock_balance on ledger INSERT (spec business rule) =====
-- Computes running balance + weighted-avg cost, writes them back onto the NEW ledger row,
-- and upserts stock_balance. BLOCKS movements that would drive on-hand negative.
create or replace function public.fn_apply_stock_ledger()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_bal   public.stock_balance;
  v_new   decimal(15,4);
  v_avg   decimal(15,4);
  v_wh_key uuid := coalesce(new.warehouse_id, '00000000-0000-0000-0000-000000000000'::uuid);
  v_var_key uuid := coalesce(new.variant_id, '00000000-0000-0000-0000-000000000000'::uuid);
begin
  select * into v_bal from public.stock_balance b
   where b.tenant_id = new.tenant_id and b.branch_id = new.branch_id
     and b.product_id = new.product_id
     and coalesce(b.warehouse_id,'00000000-0000-0000-0000-000000000000'::uuid) = v_wh_key
     and coalesce(b.variant_id, '00000000-0000-0000-0000-000000000000'::uuid)  = v_var_key
   for update;

  if not found then
    v_new := new.qty_change;
    if v_new < 0 then
      raise exception 'insufficient stock' using errcode = 'P0001';
    end if;
    v_avg := case when new.qty_change > 0 then new.cost_per_unit else 0 end;
    insert into public.stock_balance
      (tenant_id, branch_id, warehouse_id, product_id, variant_id, qty_on_hand, avg_cost, last_updated)
    values (new.tenant_id, new.branch_id, new.warehouse_id, new.product_id, new.variant_id, v_new, v_avg, now())
    returning * into v_bal;
  else
    v_new := v_bal.qty_on_hand + new.qty_change;
    if v_new < 0 then
      raise exception 'insufficient stock' using errcode = 'P0001';
    end if;
    v_avg := case
               when new.qty_change > 0 and new.cost_per_unit > 0
               then ((v_bal.qty_on_hand * v_bal.avg_cost) + (new.qty_change * new.cost_per_unit))
                    / nullif(v_bal.qty_on_hand + new.qty_change, 0)
               else v_bal.avg_cost
             end;
    update public.stock_balance
       set qty_on_hand = v_new, avg_cost = v_avg, last_updated = now(), version = version + 1
     where id = v_bal.id;
  end if;

  -- stamp computed running values back onto the ledger row
  new.balance_after  := v_new;
  new.avg_cost_after := v_avg;
  new.total_cost     := new.qty_change * new.cost_per_unit;
  return new;
end; $$;
drop trigger if exists trg_apply_stock_ledger on public.stock_ledger;
create trigger trg_apply_stock_ledger
  before insert on public.stock_ledger
  for each row execute function public.fn_apply_stock_ledger();

-- ===== RLS =====
alter table public.warehouses enable row level security;
drop policy if exists "warehouses read"   on public.warehouses;
create policy "warehouses read"   on public.warehouses for select to authenticated
  using (tenant_id = public.auth_tenant_id() and deleted_at is null);
drop policy if exists "warehouses insert" on public.warehouses;
create policy "warehouses insert" on public.warehouses for insert to authenticated
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_branch(branch_id)
              and public.auth_has_permission('inventory','create'));
drop policy if exists "warehouses update" on public.warehouses;
create policy "warehouses update" on public.warehouses for update to authenticated
  using      (tenant_id = public.auth_tenant_id() and public.auth_has_permission('inventory','update'))
  with check (tenant_id = public.auth_tenant_id());

alter table public.stock_ledger enable row level security;
drop policy if exists "ledger read" on public.stock_ledger;
create policy "ledger read" on public.stock_ledger for select to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_branch(branch_id));
revoke insert, update, delete on public.stock_ledger from anon, authenticated;

alter table public.stock_balance enable row level security;
drop policy if exists "balance read" on public.stock_balance;
create policy "balance read" on public.stock_balance for select to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_branch(branch_id));
revoke insert, update, delete on public.stock_balance from anon, authenticated;

-- ===== RPC: post_stock_movement — single write path (definer; inserts ledger; trigger does the rest) =====
create or replace function public.post_stock_movement(
  p_branch_id     uuid,
  p_warehouse_id  uuid,
  p_product_id    uuid,
  p_variant_id    uuid,
  p_operation_type stock_movement_type_enum,
  p_qty_change    numeric,
  p_cost_per_unit numeric default 0,
  p_reference_type text default 'OPENING',
  p_reference_id  uuid default null,
  p_notes         text default null
) returns public.stock_balance
language plpgsql security definer set search_path = public as $$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_uid    uuid := auth.uid();
  v_bal    public.stock_balance;
begin
  if v_tenant is null then raise exception 'no tenant' using errcode='42501'; end if;
  if not public.auth_has_permission('inventory','update') then
    raise exception 'permission denied' using errcode='42501';
  end if;
  if not public.auth_has_branch(p_branch_id) then
    raise exception 'branch not assigned to user' using errcode='42501';
  end if;
  if p_qty_change = 0 then raise exception 'qty_change must be non-zero' using errcode='22000'; end if;
  if not exists (select 1 from public.products pr
                 where pr.id=p_product_id and pr.tenant_id=v_tenant and pr.deleted_at is null) then
    raise exception 'product not in tenant' using errcode='P0002';
  end if;
  if p_warehouse_id is not null and not exists (
       select 1 from public.warehouses w
       where w.id=p_warehouse_id and w.tenant_id=v_tenant and w.branch_id=p_branch_id and w.deleted_at is null) then
    raise exception 'warehouse not in branch' using errcode='P0002';
  end if;

  -- the trigger computes balance_after/avg_cost_after/total_cost and guards negatives
  insert into public.stock_ledger
    (tenant_id, product_id, variant_id, branch_id, warehouse_id, operation_type, qty_change,
     cost_per_unit, balance_after, reference_id, reference_type, notes, created_by)
  values (v_tenant, p_product_id, p_variant_id, p_branch_id, p_warehouse_id, p_operation_type, p_qty_change,
     coalesce(p_cost_per_unit,0), 0, coalesce(p_reference_id, gen_random_uuid()),
     coalesce(p_reference_type,'OPENING'), p_notes, v_uid);

  select * into v_bal from public.stock_balance b
   where b.tenant_id=v_tenant and b.branch_id=p_branch_id and b.product_id=p_product_id
     and coalesce(b.warehouse_id,'00000000-0000-0000-0000-000000000000'::uuid)
       = coalesce(p_warehouse_id,'00000000-0000-0000-0000-000000000000'::uuid)
     and coalesce(b.variant_id,'00000000-0000-0000-0000-000000000000'::uuid)
       = coalesce(p_variant_id,'00000000-0000-0000-0000-000000000000'::uuid);
  return v_bal;
end; $$;
revoke all on function public.post_stock_movement(uuid,uuid,uuid,uuid,stock_movement_type_enum,numeric,numeric,text,uuid,text) from anon, public;
grant execute on function public.post_stock_movement(uuid,uuid,uuid,uuid,stock_movement_type_enum,numeric,numeric,text,uuid,text) to authenticated;

-- ===== RPC: warehouse soft-delete / set-default / ensure-default =====
create or replace function public.soft_delete_warehouse(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.auth_has_permission('inventory','delete') then
    raise exception 'permission denied' using errcode='42501';
  end if;
  if exists (select 1 from public.stock_balance b where b.warehouse_id=p_id and b.qty_on_hand <> 0) then
    raise exception 'warehouse has stock' using errcode='P0001';
  end if;
  update public.warehouses set deleted_at=now(), updated_by=auth.uid()
   where id=p_id and tenant_id=public.auth_tenant_id() and deleted_at is null;
  if not found then raise exception 'warehouse not found in tenant' using errcode='P0002'; end if;
end; $$;
revoke all on function public.soft_delete_warehouse(uuid) from anon, public;
grant execute on function public.soft_delete_warehouse(uuid) to authenticated;

create or replace function public.set_default_warehouse(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); v_branch uuid;
begin
  if not public.auth_has_permission('inventory','update') then
    raise exception 'permission denied' using errcode='42501';
  end if;
  select branch_id into v_branch from public.warehouses
   where id=p_id and tenant_id=v_tenant and deleted_at is null;
  if v_branch is null then raise exception 'warehouse not found' using errcode='P0002'; end if;
  update public.warehouses set is_default=false, updated_by=auth.uid()
   where tenant_id=v_tenant and branch_id=v_branch and is_default and deleted_at is null;
  update public.warehouses set is_default=true, updated_by=auth.uid() where id=p_id;
end; $$;
revoke all on function public.set_default_warehouse(uuid) from anon, public;
grant execute on function public.set_default_warehouse(uuid) to authenticated;

create or replace function public.ensure_default_warehouse(p_branch_id uuid)
returns public.warehouses language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); v_wh public.warehouses;
begin
  if not public.auth_has_branch(p_branch_id) then
    raise exception 'branch not assigned' using errcode='42501';
  end if;
  select * into v_wh from public.warehouses
   where tenant_id=v_tenant and branch_id=p_branch_id and deleted_at is null
   order by is_default desc, created_at limit 1;
  if found then return v_wh; end if;
  insert into public.warehouses (tenant_id, branch_id, name, code, is_default, is_active, created_by)
  values (v_tenant, p_branch_id, 'Main Warehouse', 'WH01', true, true, auth.uid())
  returning * into v_wh;
  return v_wh;
end; $$;
revoke all on function public.ensure_default_warehouse(uuid) from anon, public;
grant execute on function public.ensure_default_warehouse(uuid) to authenticated;

-- ===== Seed: one default warehouse per existing branch that has none =====
insert into public.warehouses (tenant_id, branch_id, name, code, is_default, is_active)
select b.tenant_id, b.id, 'Main Warehouse', 'WH01', true, true
from public.branches b
where not exists (select 1 from public.warehouses w where w.branch_id=b.id and w.deleted_at is null);