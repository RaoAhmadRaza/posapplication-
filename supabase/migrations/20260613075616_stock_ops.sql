-- <timestamp>_stock_ops.sql  (Slice C — Stock Ops)
-- imei_records, stock_transfers(+items), stock_adjustments, stock_counts(+items), number_series,
-- inventory_settings, and RPCs that post through the Slice B ledger. Additive + idempotent.

-- ===== enums (verbatim) =====
do $$ begin create type imei_status_enum            as enum ('AVAILABLE','SOLD','RETURNED','TRANSFERRED','SCRAPPED','RESERVED','IN_TRANSIT'); exception when duplicate_object then null; end $$;
do $$ begin create type stock_transfer_status_enum  as enum ('DRAFT','IN_TRANSIT','PARTIALLY_RECEIVED','RECEIVED','CANCELLED'); exception when duplicate_object then null; end $$;
do $$ begin create type stock_count_status_enum     as enum ('DRAFT','IN_PROGRESS','COMPLETED','CANCELLED'); exception when duplicate_object then null; end $$;
do $$ begin create type adjustment_reason_enum      as enum ('DAMAGE','THEFT','EXPIRED','RECOUNT','OPENING_BALANCE','WRITE_OFF','OTHER'); exception when duplicate_object then null; end $$;
do $$ begin create type number_series_type_enum     as enum ('INVOICE','PURCHASE_ORDER','GRN','JOURNAL_ENTRY','STOCK_TRANSFER','STOCK_COUNT','REPAIR_JOB','PAYMENT_VOUCHER','RECEIPT_VOUCHER'); exception when duplicate_object then null; end $$;

-- ===== inventory_settings (GAP-FIX #1: approval threshold) =====
create table if not exists public.inventory_settings (
  tenant_id uuid primary key references public.tenants(id),
  adjustment_approval_threshold decimal(15,4) not null default 0,  -- abs(adj_qty*cost) at/above => needs approval; 0 => never
  allow_negative_stock boolean not null default false,             -- honored by post_stock_movement
  updated_at timestamptz not null default now()
);
insert into public.inventory_settings (tenant_id)
select id from public.tenants on conflict (tenant_id) do nothing;
alter table public.inventory_settings enable row level security;
drop policy if exists "inv_settings read" on public.inventory_settings;
create policy "inv_settings read" on public.inventory_settings for select to authenticated using (tenant_id = public.auth_tenant_id());
drop policy if exists "inv_settings update" on public.inventory_settings;
create policy "inv_settings update" on public.inventory_settings for update to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('settings','update'))
  with check (tenant_id = public.auth_tenant_id());

-- ===== number_series (GAP-FIX #2) =====
create table if not exists public.number_series (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid references public.branches(id),
  type number_series_type_enum not null,
  prefix varchar(20) not null default '',
  suffix varchar(20) not null default '',
  current_number integer not null default 0,
  padding integer not null default 6,
  fiscal_year_reset boolean not null default false,
  include_branch_code boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists uq_number_series on public.number_series(tenant_id, branch_id, type);
alter table public.number_series enable row level security;
drop policy if exists "number_series read" on public.number_series;
create policy "number_series read" on public.number_series for select to authenticated using (tenant_id = public.auth_tenant_id());
revoke insert, update, delete on public.number_series from anon, authenticated;  -- only the RPC mutates

-- gap-safe next-number RPC (SELECT FOR UPDATE per spec business rule)
create or replace function public.next_number(p_type number_series_type_enum, p_branch_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); v_row public.number_series; v_n int; v_code text := '';
begin
  if v_tenant is null then raise exception 'no tenant' using errcode='42501'; end if;
  select * into v_row from public.number_series
   where tenant_id=v_tenant and type=p_type
     and (branch_id = p_branch_id or branch_id is null)
   order by branch_id nulls last limit 1
   for update;
  if not found then
    insert into public.number_series (tenant_id, branch_id, type) values (v_tenant, p_branch_id, p_type)
    returning * into v_row;
  end if;
  v_n := v_row.current_number + 1;
  update public.number_series set current_number = v_n, updated_at = now() where id = v_row.id;
  if v_row.include_branch_code then
    select coalesce(code,'') into v_code from public.branches where id = p_branch_id;
    if v_code <> '' then v_code := v_code || '-'; end if;
  end if;
  return v_row.prefix || v_code || lpad(v_n::text, v_row.padding, '0') || v_row.suffix;
end; $$;
revoke all on function public.next_number(number_series_type_enum,uuid) from anon, public;
grant execute on function public.next_number(number_series_type_enum,uuid) to authenticated;
-- seed STOCK_TRANSFER + STOCK_COUNT series per tenant (prefixes)
insert into public.number_series (tenant_id, branch_id, type, prefix)
select t.id, null, 'STOCK_TRANSFER', 'TRF-' from public.tenants t
on conflict (tenant_id, branch_id, type) do nothing;
insert into public.number_series (tenant_id, branch_id, type, prefix)
select t.id, null, 'STOCK_COUNT', 'CNT-' from public.tenants t
on conflict (tenant_id, branch_id, type) do nothing;

-- ===== imei_records (schema doc verbatim; GLOBAL unique imei) =====
create table if not exists public.imei_records (
  id            uuid primary key default gen_random_uuid(),
  tenant_id     uuid not null references public.tenants(id),
  imei          varchar(50) not null,
  product_id    uuid not null references public.products(id),
  variant_id    uuid references public.product_variants(id),
  status        imei_status_enum not null default 'AVAILABLE',
  branch_id     uuid not null references public.branches(id),
  warehouse_id  uuid references public.warehouses(id),
  source_type   varchar(50) not null,    -- PURCHASE, OPENING_BALANCE, TRANSFER
  source_id     uuid,
  sold_invoice_id uuid,                   -- FK → invoices added in Sales module
  cost_price    decimal(15,4) not null default 0,
  selling_price decimal(15,4),
  warranty_expires_at date,
  notes         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  version       integer not null default 1,
  created_by    uuid references public.users(id),
  updated_by    uuid references public.users(id)
);
create unique index if not exists uq_imei_records_imei on public.imei_records(imei);  -- GLOBAL
create index if not exists idx_imei_records_product on public.imei_records(product_id, status);
create index if not exists idx_imei_records_branch  on public.imei_records(branch_id, status);
create index if not exists idx_imei_records_tenant_status on public.imei_records(tenant_id, status);
drop trigger if exists trg_imei_touch on public.imei_records;
create trigger trg_imei_touch before update on public.imei_records for each row execute function public.fn_touch_row();
-- now that imei_records exists, add the deferred FK on stock_ledger (GAP-FIX #5)
do $$ begin
  alter table public.stock_ledger add constraint fk_stock_ledger_imei foreign key (imei_id) references public.imei_records(id);
exception when duplicate_object then null; when undefined_column then null; end $$;

-- ===== stock_adjustments (schema doc verbatim) =====
create table if not exists public.stock_adjustments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid not null references public.branches(id),
  warehouse_id uuid references public.warehouses(id),
  product_id uuid not null references public.products(id),
  variant_id uuid references public.product_variants(id),
  adj_qty decimal(15,4) not null,            -- + increase / - decrease
  cost_per_unit decimal(15,4) not null default 0,
  reason_code adjustment_reason_enum not null,
  reason_notes text,
  reference_number varchar(50),
  requires_approval boolean not null default false,
  approved_by uuid references public.users(id),
  approved_at timestamptz,
  posted boolean not null default false,     -- has it hit the ledger yet
  correlation_id uuid,
  created_at timestamptz not null default now(),
  created_by uuid references public.users(id)
);
create index if not exists idx_adjustments_branch  on public.stock_adjustments(branch_id, created_at);
create index if not exists idx_adjustments_product on public.stock_adjustments(product_id);
create index if not exists idx_adjustments_tenant  on public.stock_adjustments(tenant_id, created_at);
create index if not exists idx_adjustments_pending on public.stock_adjustments(tenant_id) where requires_approval = true and approved_by is null;
alter table public.stock_adjustments enable row level security;
drop policy if exists "adj read" on public.stock_adjustments;
create policy "adj read" on public.stock_adjustments for select to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_branch(branch_id));
revoke insert, update, delete on public.stock_adjustments from anon, authenticated;  -- only RPCs mutate

-- ===== stock_transfers (+ items) (schema doc verbatim) =====
create table if not exists public.stock_transfers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  transfer_number varchar(50) not null,
  from_branch_id uuid not null references public.branches(id),
  to_branch_id uuid not null references public.branches(id),
  from_warehouse_id uuid references public.warehouses(id),
  to_warehouse_id uuid references public.warehouses(id),
  status stock_transfer_status_enum not null default 'DRAFT',
  dispatched_at timestamptz, dispatched_by uuid references public.users(id),
  received_at timestamptz,   received_by uuid references public.users(id),
  notes text, correlation_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz, version integer not null default 1,
  created_by uuid references public.users(id), updated_by uuid references public.users(id),
  constraint chk_transfers_different_branches check (from_branch_id <> to_branch_id)
);
create unique index if not exists uq_transfer_tenant_number on public.stock_transfers(tenant_id, transfer_number) where deleted_at is null;
create index if not exists idx_transfers_from on public.stock_transfers(from_branch_id, status) where deleted_at is null;
create index if not exists idx_transfers_to   on public.stock_transfers(to_branch_id, status)   where deleted_at is null;
drop trigger if exists trg_transfers_touch on public.stock_transfers;
create trigger trg_transfers_touch before update on public.stock_transfers for each row execute function public.fn_touch_row();

create table if not exists public.stock_transfer_items (
  id uuid primary key default gen_random_uuid(),
  transfer_id uuid not null references public.stock_transfers(id) on delete cascade,
  product_id uuid not null references public.products(id),
  variant_id uuid references public.product_variants(id),
  imei_id uuid references public.imei_records(id),
  qty decimal(15,4) not null,
  qty_received decimal(15,4) not null default 0,
  cost_price decimal(15,4) not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  constraint chk_transfer_items_qty check (qty > 0)
);
create index if not exists idx_transfer_items_transfer on public.stock_transfer_items(transfer_id);
create index if not exists idx_transfer_items_product  on public.stock_transfer_items(product_id);

alter table public.stock_transfers enable row level security;
drop policy if exists "transfers read" on public.stock_transfers;
create policy "transfers read" on public.stock_transfers for select to authenticated
  using (tenant_id = public.auth_tenant_id() and (public.auth_has_branch(from_branch_id) or public.auth_has_branch(to_branch_id)));
revoke insert, update, delete on public.stock_transfers from anon, authenticated;
alter table public.stock_transfer_items enable row level security;
drop policy if exists "transfer_items read" on public.stock_transfer_items;
create policy "transfer_items read" on public.stock_transfer_items for select to authenticated
  using (exists (select 1 from public.stock_transfers t where t.id = transfer_id and t.tenant_id = public.auth_tenant_id()));
revoke insert, update, delete on public.stock_transfer_items from anon, authenticated;

-- ===== stock_counts (+ items) (schema doc verbatim) =====
create table if not exists public.stock_counts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid not null references public.branches(id),
  warehouse_id uuid references public.warehouses(id),
  count_number varchar(50) not null,
  status stock_count_status_enum not null default 'DRAFT',
  category_id uuid references public.categories(id),
  started_at timestamptz, completed_at timestamptz,
  total_items integer not null default 0,
  items_counted integer not null default 0,
  variance_count integer not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1,
  created_by uuid references public.users(id), updated_by uuid references public.users(id)
);
create unique index if not exists uq_stock_counts_number on public.stock_counts(tenant_id, count_number);
create index if not exists idx_stock_counts_branch on public.stock_counts(branch_id, status);
drop trigger if exists trg_counts_touch on public.stock_counts;
create trigger trg_counts_touch before update on public.stock_counts for each row execute function public.fn_touch_row();

create table if not exists public.stock_count_items (
  id uuid primary key default gen_random_uuid(),
  stock_count_id uuid not null references public.stock_counts(id) on delete cascade,
  product_id uuid not null references public.products(id),
  variant_id uuid references public.product_variants(id),
  system_qty decimal(15,4) not null,
  counted_qty decimal(15,4),
  variance decimal(15,4),
  variance_cost decimal(15,4),
  notes text,
  counted_at timestamptz, counted_by uuid references public.users(id),
  created_at timestamptz not null default now()
);
create index if not exists idx_stock_count_items_count on public.stock_count_items(stock_count_id);
create unique index if not exists uq_stock_count_items on public.stock_count_items(stock_count_id, product_id);

alter table public.stock_counts enable row level security;
drop policy if exists "counts read" on public.stock_counts;
create policy "counts read" on public.stock_counts for select to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_branch(branch_id));
revoke insert, update, delete on public.stock_counts from anon, authenticated;
alter table public.stock_count_items enable row level security;
drop policy if exists "count_items read" on public.stock_count_items;
create policy "count_items read" on public.stock_count_items for select to authenticated
  using (exists (select 1 from public.stock_counts c where c.id = stock_count_id and c.tenant_id = public.auth_tenant_id()));
revoke insert, update, delete on public.stock_count_items from anon, authenticated;

-- imei RLS
alter table public.imei_records enable row level security;
drop policy if exists "imei read" on public.imei_records;
create policy "imei read" on public.imei_records for select to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_branch(branch_id));
revoke insert, update, delete on public.imei_records from anon, authenticated;  -- mutated via RPCs

-- =========================================================================
-- RPCs (all SECURITY DEFINER; all stock movement goes through Slice B ledger)
-- =========================================================================

-- ADJUSTMENTS: create (threshold decides approval); approve+post; reject.
create or replace function public.create_stock_adjustment(
  p_branch_id uuid, p_warehouse_id uuid, p_product_id uuid, p_variant_id uuid,
  p_adj_qty numeric, p_cost_per_unit numeric, p_reason adjustment_reason_enum, p_notes text default null
) returns public.stock_adjustments language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); v_thr decimal(15,4); v_needs boolean; v_row public.stock_adjustments; v_uid uuid := auth.uid();
begin
  if v_tenant is null then raise exception 'no tenant' using errcode='42501'; end if;
  if not public.auth_has_permission('inventory','update') then raise exception 'permission denied' using errcode='42501'; end if;
  if not public.auth_has_branch(p_branch_id) then raise exception 'branch not assigned' using errcode='42501'; end if;
  if p_adj_qty = 0 then raise exception 'adj_qty must be non-zero' using errcode='22000'; end if;
  select adjustment_approval_threshold into v_thr from public.inventory_settings where tenant_id=v_tenant;
  v_needs := coalesce(v_thr,0) > 0 and abs(p_adj_qty * coalesce(p_cost_per_unit,0)) >= v_thr;
  insert into public.stock_adjustments
    (tenant_id,branch_id,warehouse_id,product_id,variant_id,adj_qty,cost_per_unit,reason_code,reason_notes,requires_approval,created_by)
  values (v_tenant,p_branch_id,p_warehouse_id,p_product_id,p_variant_id,p_adj_qty,coalesce(p_cost_per_unit,0),p_reason,p_notes,v_needs,v_uid)
  returning * into v_row;
  if not v_needs then
    perform public.post_stock_movement(p_branch_id,p_warehouse_id,p_product_id,p_variant_id,
      case when p_reason in ('WRITE_OFF','DAMAGE','THEFT','EXPIRED') and p_adj_qty<0 then 'SCRAP'::stock_movement_type_enum else 'ADJUSTMENT'::stock_movement_type_enum end,
      p_adj_qty, p_cost_per_unit, 'ADJUSTMENT', v_row.id, p_notes);
    update public.stock_adjustments set posted=true, approved_by=v_uid, approved_at=now() where id=v_row.id returning * into v_row;
  end if;
  return v_row;
end; $$;
revoke all on function public.create_stock_adjustment(uuid,uuid,uuid,uuid,numeric,numeric,adjustment_reason_enum,text) from anon, public;
grant execute on function public.create_stock_adjustment(uuid,uuid,uuid,uuid,numeric,numeric,adjustment_reason_enum,text) to authenticated;

create or replace function public.approve_stock_adjustment(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); a public.stock_adjustments;
begin
  if not public.auth_has_permission('inventory','approve') then raise exception 'permission denied' using errcode='42501'; end if;
  select * into a from public.stock_adjustments where id=p_id and tenant_id=v_tenant for update;
  if not found then raise exception 'adjustment not found' using errcode='P0002'; end if;
  if a.posted then raise exception 'already posted' using errcode='22000'; end if;
  perform public.post_stock_movement(a.branch_id,a.warehouse_id,a.product_id,a.variant_id,
    case when a.reason_code in ('WRITE_OFF','DAMAGE','THEFT','EXPIRED') and a.adj_qty<0 then 'SCRAP'::stock_movement_type_enum else 'ADJUSTMENT'::stock_movement_type_enum end,
    a.adj_qty, a.cost_per_unit, 'ADJUSTMENT', a.id, a.reason_notes);
  update public.stock_adjustments set posted=true, approved_by=auth.uid(), approved_at=now(), requires_approval=false where id=p_id;
end; $$;
revoke all on function public.approve_stock_adjustment(uuid) from anon, public;
grant execute on function public.approve_stock_adjustment(uuid) to authenticated;

-- TRANSFERS: create (DRAFT), dispatch (TRANSFER_OUT + in_transit), receive (TRANSFER_IN), cancel.
create or replace function public.create_stock_transfer(
  p_from_branch uuid, p_to_branch uuid, p_from_wh uuid, p_to_wh uuid, p_notes text,
  p_items jsonb  -- [{product_id, variant_id, qty, cost_price}]
) returns public.stock_transfers language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); v_t public.stock_transfers; v_num text; it jsonb;
begin
  if not public.auth_has_permission('inventory','create') then raise exception 'permission denied' using errcode='42501'; end if;
  if not public.auth_has_branch(p_from_branch) then raise exception 'source branch not assigned' using errcode='42501'; end if;
  if p_from_branch = p_to_branch then raise exception 'branches must differ' using errcode='22000'; end if;
  v_num := public.next_number('STOCK_TRANSFER', p_from_branch);
  insert into public.stock_transfers (tenant_id,transfer_number,from_branch_id,to_branch_id,from_warehouse_id,to_warehouse_id,status,notes,created_by)
  values (v_tenant,v_num,p_from_branch,p_to_branch,p_from_wh,p_to_wh,'DRAFT',p_notes,auth.uid()) returning * into v_t;
  for it in select * from jsonb_array_elements(p_items) loop
    insert into public.stock_transfer_items (transfer_id,product_id,variant_id,qty,cost_price)
    values (v_t.id,(it->>'product_id')::uuid, nullif(it->>'variant_id','')::uuid,(it->>'qty')::numeric, coalesce((it->>'cost_price')::numeric,0));
  end loop;
  return v_t;
end; $$;
revoke all on function public.create_stock_transfer(uuid,uuid,uuid,uuid,text,jsonb) from anon, public;
grant execute on function public.create_stock_transfer(uuid,uuid,uuid,uuid,text,jsonb) to authenticated;

create or replace function public.dispatch_stock_transfer(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); t public.stock_transfers; it public.stock_transfer_items;
begin
  if not public.auth_has_permission('inventory','update') then raise exception 'permission denied' using errcode='42501'; end if;
  select * into t from public.stock_transfers where id=p_id and tenant_id=v_tenant for update;
  if not found then raise exception 'transfer not found' using errcode='P0002'; end if;
  if t.status <> 'DRAFT' then raise exception 'only DRAFT can dispatch' using errcode='22000'; end if;
  if not public.auth_has_branch(t.from_branch_id) then raise exception 'not source branch' using errcode='42501'; end if;
  for it in select * from public.stock_transfer_items where transfer_id=p_id loop
    perform public.post_stock_movement(t.from_branch_id,t.from_warehouse_id,it.product_id,it.variant_id,
      'TRANSFER_OUT', -1*it.qty, it.cost_price, 'TRANSFER', t.id, 'dispatch');
  end loop;
  update public.stock_transfers set status='IN_TRANSIT', dispatched_at=now(), dispatched_by=auth.uid() where id=p_id;
end; $$;
revoke all on function public.dispatch_stock_transfer(uuid) from anon, public;
grant execute on function public.dispatch_stock_transfer(uuid) to authenticated;

create or replace function public.receive_stock_transfer(p_id uuid, p_received jsonb)
-- p_received: [{item_id, qty_received}]
returns void language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); t public.stock_transfers; r jsonb; it public.stock_transfer_items; v_all boolean := true;
begin
  if not public.auth_has_permission('inventory','update') then raise exception 'permission denied' using errcode='42501'; end if;
  select * into t from public.stock_transfers where id=p_id and tenant_id=v_tenant for update;
  if not found then raise exception 'transfer not found' using errcode='P0002'; end if;
  if t.status not in ('IN_TRANSIT','PARTIALLY_RECEIVED') then raise exception 'not receivable' using errcode='22000'; end if;
  if not public.auth_has_branch(t.to_branch_id) then raise exception 'not destination branch' using errcode='42501'; end if;
  for r in select * from jsonb_array_elements(p_received) loop
    select * into it from public.stock_transfer_items where id=(r->>'item_id')::uuid and transfer_id=p_id for update;
    if found and (r->>'qty_received')::numeric > 0 then
      perform public.post_stock_movement(t.to_branch_id,t.to_warehouse_id,it.product_id,it.variant_id,
        'TRANSFER_IN', (r->>'qty_received')::numeric, it.cost_price, 'TRANSFER', t.id, 'receive');
      update public.stock_transfer_items set qty_received = qty_received + (r->>'qty_received')::numeric where id=it.id;
    end if;
  end loop;
  select bool_and(qty_received >= qty) into v_all from public.stock_transfer_items where transfer_id=p_id;
  update public.stock_transfers set status = case when v_all then 'RECEIVED' else 'PARTIALLY_RECEIVED' end,
         received_at = case when v_all then now() else received_at end,
         received_by = case when v_all then auth.uid() else received_by end
   where id=p_id;
end; $$;
revoke all on function public.receive_stock_transfer(uuid,jsonb) from anon, public;
grant execute on function public.receive_stock_transfer(uuid,jsonb) to authenticated;

create or replace function public.cancel_stock_transfer(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); t public.stock_transfers; it public.stock_transfer_items;
begin
  if not public.auth_has_permission('inventory','update') then raise exception 'permission denied' using errcode='42501'; end if;
  select * into t from public.stock_transfers where id=p_id and tenant_id=v_tenant for update;
  if not found then raise exception 'transfer not found' using errcode='P0002'; end if;
  if t.status = 'DRAFT' then
    update public.stock_transfers set status='CANCELLED' where id=p_id;
  elsif t.status = 'IN_TRANSIT' then
    -- return dispatched stock to source
    for it in select * from public.stock_transfer_items where transfer_id=p_id loop
      perform public.post_stock_movement(t.from_branch_id,t.from_warehouse_id,it.product_id,it.variant_id,
        'TRANSFER_IN', it.qty - it.qty_received, it.cost_price, 'TRANSFER', t.id, 'cancel-return');
    end loop;
    update public.stock_transfers set status='CANCELLED' where id=p_id;
  else
    raise exception 'cannot cancel in status %', t.status using errcode='22000';
  end if;
end; $$;
revoke all on function public.cancel_stock_transfer(uuid) from anon, public;
grant execute on function public.cancel_stock_transfer(uuid) to authenticated;

-- COUNTS: open (snapshot system_qty), record line, complete (post variance ADJUSTMENTs).
create or replace function public.open_stock_count(p_branch uuid, p_warehouse uuid, p_category uuid default null)
returns public.stock_counts language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); c public.stock_counts; v_num text; v_total int;
begin
  if not public.auth_has_permission('inventory','update') then raise exception 'permission denied' using errcode='42501'; end if;
  if not public.auth_has_branch(p_branch) then raise exception 'branch not assigned' using errcode='42501'; end if;
  v_num := public.next_number('STOCK_COUNT', p_branch);
  insert into public.stock_counts (tenant_id,branch_id,warehouse_id,count_number,status,category_id,started_at,created_by)
  values (v_tenant,p_branch,p_warehouse,v_num,'IN_PROGRESS',p_category,now(),auth.uid()) returning * into c;
  -- snapshot current system qty for in-scope products that have a balance row
  insert into public.stock_count_items (stock_count_id, product_id, variant_id, system_qty)
  select c.id, b.product_id, b.variant_id, b.qty_on_hand
  from public.stock_balance b
  join public.products p on p.id=b.product_id and p.deleted_at is null
  where b.tenant_id=v_tenant and b.branch_id=p_branch
    and coalesce(b.warehouse_id,'00000000-0000-0000-0000-000000000000'::uuid)=coalesce(p_warehouse,'00000000-0000-0000-0000-000000000000'::uuid)
    and (p_category is null or p.category_id=p_category);
  select count(*) into v_total from public.stock_count_items where stock_count_id=c.id;
  update public.stock_counts set total_items=v_total where id=c.id returning * into c;
  return c;
end; $$;
revoke all on function public.open_stock_count(uuid,uuid,uuid) from anon, public;
grant execute on function public.open_stock_count(uuid,uuid,uuid) to authenticated;

create or replace function public.record_count_item(p_item_id uuid, p_counted numeric)
returns void language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); ci public.stock_count_items; v_avg decimal(15,4); v_cid uuid;
begin
  if not public.auth_has_permission('inventory','update') then raise exception 'permission denied' using errcode='42501'; end if;
  select * into ci from public.stock_count_items where id=p_item_id for update;
  if not found then raise exception 'count item not found' using errcode='P0002'; end if;
  select avg_cost into v_avg from public.stock_balance b where b.product_id=ci.product_id limit 1;
  update public.stock_count_items
     set counted_qty=p_counted, variance=p_counted-system_qty, variance_cost=(p_counted-system_qty)*coalesce(v_avg,0),
         counted_at=now(), counted_by=auth.uid()
   where id=p_item_id;
  update public.stock_counts c set items_counted=(select count(*) from public.stock_count_items where stock_count_id=c.id and counted_qty is not null),
         variance_count=(select count(*) from public.stock_count_items where stock_count_id=c.id and variance is not null and variance<>0)
   where c.id=ci.stock_count_id;
end; $$;
revoke all on function public.record_count_item(uuid,numeric) from anon, public;
grant execute on function public.record_count_item(uuid,numeric) to authenticated;

create or replace function public.complete_stock_count(p_id uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); c public.stock_counts; ci public.stock_count_items;
begin
  if not public.auth_has_permission('inventory','approve') then raise exception 'permission denied' using errcode='42501'; end if;
  select * into c from public.stock_counts where id=p_id and tenant_id=v_tenant for update;
  if not found then raise exception 'count not found' using errcode='P0002'; end if;
  if c.status <> 'IN_PROGRESS' then raise exception 'not in progress' using errcode='22000'; end if;
  for ci in select * from public.stock_count_items where stock_count_id=p_id and variance is not null and variance<>0 loop
    perform public.post_stock_movement(c.branch_id,c.warehouse_id,ci.product_id,ci.variant_id,
      'ADJUSTMENT', ci.variance, coalesce(ci.variance_cost / nullif(ci.variance,0),0), 'COUNT', c.id, 'count reconcile');
  end loop;
  update public.stock_counts set status='COMPLETED', completed_at=now() where id=p_id;
  -- stamp last_stock_take on affected balances
  update public.stock_balance set last_stock_take=now()
   where tenant_id=v_tenant and branch_id=c.branch_id
     and coalesce(warehouse_id,'00000000-0000-0000-0000-000000000000'::uuid)=coalesce(c.warehouse_id,'00000000-0000-0000-0000-000000000000'::uuid);
end; $$;
revoke all on function public.complete_stock_count(uuid) from anon, public;
grant execute on function public.complete_stock_count(uuid) to authenticated;

-- IMEI: register (capture serials, optionally posts OPENING/PURCHASE qty), set status.
create or replace function public.register_imei(
  p_product uuid, p_variant uuid, p_branch uuid, p_warehouse uuid, p_imei text,
  p_source_type text, p_cost numeric, p_post_stock boolean default true
) returns public.imei_records language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); r public.imei_records;
begin
  if not public.auth_has_permission('inventory','create') then raise exception 'permission denied' using errcode='42501'; end if;
  if not public.auth_has_branch(p_branch) then raise exception 'branch not assigned' using errcode='42501'; end if;
  begin
    insert into public.imei_records (tenant_id,imei,product_id,variant_id,status,branch_id,warehouse_id,source_type,cost_price,created_by)
    values (v_tenant,p_imei,p_product,p_variant,'AVAILABLE',p_branch,p_warehouse,coalesce(p_source_type,'OPENING_BALANCE'),coalesce(p_cost,0),auth.uid())
    returning * into r;
  exception when unique_violation then
    raise exception 'duplicate imei' using errcode='23505';
  end;
  if p_post_stock then
    perform public.post_stock_movement(p_branch,p_warehouse,p_product,p_variant,'OPENING_BALANCE',1,p_cost,'IMEI',r.id,'imei register');
  end if;
  return r;
end; $$;
revoke all on function public.register_imei(uuid,uuid,uuid,uuid,text,text,numeric,boolean) from anon, public;
grant execute on function public.register_imei(uuid,uuid,uuid,uuid,text,text,numeric,boolean) to authenticated;