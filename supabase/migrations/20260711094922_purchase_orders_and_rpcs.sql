-- ========== TABLES (verbatim §3.6) ==========
create table if not exists public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid not null references public.branches(id),
  supplier_id uuid not null references public.suppliers(id),
  po_number varchar(50) not null,
  status purchase_order_status_enum not null default 'DRAFT',
  order_date date not null default current_date,
  expected_date date,
  currency varchar(3) not null default 'PKR',
  exchange_rate decimal(10,6) not null default 1.0,
  subtotal decimal(15,4) not null default 0,
  tax_total decimal(15,4) not null default 0,
  discount_total decimal(15,4) not null default 0,
  freight_charges decimal(15,4) not null default 0,
  insurance_charges decimal(15,4) not null default 0,
  custom_duty decimal(15,4) not null default 0,
  landed_cost decimal(15,4) not null default 0,
  grand_total decimal(15,4) not null default 0,
  notes text,
  approved_by uuid references public.users(id),
  approved_at timestamptz,
  correlation_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  version integer not null default 1,
  created_by uuid references public.users(id),
  updated_by uuid references public.users(id)
);
create unique index if not exists uq_po_tenant_number on public.purchase_orders(tenant_id, po_number) where deleted_at is null;
create index if not exists idx_po_supplier       on public.purchase_orders(supplier_id, status) where deleted_at is null;
create index if not exists idx_po_branch_created  on public.purchase_orders(branch_id, created_at) where deleted_at is null;
create index if not exists idx_po_status          on public.purchase_orders(tenant_id, status) where deleted_at is null;

create table if not exists public.purchase_order_items (
  id uuid primary key default gen_random_uuid(),
  po_id uuid not null references public.purchase_orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  variant_id uuid references public.product_variants(id),
  qty_ordered decimal(15,4) not null,
  qty_received decimal(15,4) not null default 0,
  unit_cost decimal(15,4) not null,
  unit_cost_base decimal(15,4) not null,
  tax_pct decimal(5,2) not null default 0,
  discount_pct decimal(5,2) not null default 0,
  line_total decimal(15,4) not null,
  landed_cost_allocated decimal(15,4) not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists idx_po_items_po      on public.purchase_order_items(po_id);
create index if not exists idx_po_items_product on public.purchase_order_items(product_id);
do $$ begin
  alter table public.purchase_order_items add constraint chk_po_items_qty check (qty_ordered > 0);
exception when duplicate_object then null; end $$;
do $$ begin
  alter table public.purchase_order_items add constraint chk_po_items_received check (qty_received >= 0 and qty_received <= qty_ordered);
exception when duplicate_object then null; end $$;

-- ========== RLS: client reads tenant rows; ALL writes via RPC ==========
alter table public.purchase_orders enable row level security;
drop policy if exists "po tenant read" on public.purchase_orders;
create policy "po tenant read" on public.purchase_orders
  for select to authenticated using (tenant_id = public.auth_tenant_id());
revoke insert, update, delete on public.purchase_orders from authenticated;

alter table public.purchase_order_items enable row level security;
drop policy if exists "po_items tenant read" on public.purchase_order_items;
create policy "po_items tenant read" on public.purchase_order_items
  for select to authenticated using (
    exists (select 1 from public.purchase_orders po
            where po.id = po_id and po.tenant_id = public.auth_tenant_id()));
revoke insert, update, delete on public.purchase_order_items from authenticated;

-- ========== RPC: create_purchase_order ==========
-- p_items jsonb array of {product_id, variant_id?, qty_ordered, unit_cost, tax_pct?, discount_pct?}
create or replace function public.create_purchase_order(
  p_branch_id uuid,
  p_supplier_id uuid,
  p_order_date date,
  p_expected_date date,
  p_currency varchar,
  p_exchange_rate numeric,
  p_freight numeric,
  p_insurance numeric,
  p_custom_duty numeric,
  p_discount_total numeric,
  p_notes text,
  p_items jsonb
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id();
  v_uid uuid := auth.uid();
  v_po_id uuid;
  v_num text;
  v_rate numeric := coalesce(nullif(p_exchange_rate,0), 1.0);
  v_item jsonb;
  v_qty numeric; v_cost numeric; v_taxp numeric; v_discp numeric;
  v_line numeric; v_line_tax numeric;
  v_subtotal numeric := 0; v_tax_total numeric := 0;
  v_landed numeric := coalesce(p_freight,0)+coalesce(p_insurance,0)+coalesce(p_custom_duty,0);
  v_grand numeric;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not public.auth_has_branch(p_branch_id) then raise exception 'ERR_BRANCH_NOT_ASSIGNED' using errcode='42501'; end if;
  if not exists (select 1 from suppliers s where s.id=p_supplier_id and s.tenant_id=v_t and s.deleted_at is null) then
    raise exception 'ERR_SUPPLIER_NOT_FOUND'; end if;
  if p_items is null or jsonb_array_length(p_items) = 0 then raise exception 'ERR_NO_ITEMS'; end if;

  v_num := public.next_number('PURCHASE_ORDER', p_branch_id);

  insert into purchase_orders (tenant_id, branch_id, supplier_id, po_number, status, order_date,
    expected_date, currency, exchange_rate, discount_total, freight_charges, insurance_charges,
    custom_duty, landed_cost, notes, created_by, updated_by)
  values (v_t, p_branch_id, p_supplier_id, v_num, 'DRAFT', coalesce(p_order_date, current_date),
    p_expected_date, coalesce(p_currency,'PKR'), v_rate, coalesce(p_discount_total,0),
    coalesce(p_freight,0), coalesce(p_insurance,0), coalesce(p_custom_duty,0), v_landed,
    p_notes, v_uid, v_uid)
  returning id into v_po_id;

  -- insert lines, accumulate subtotal + tax
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty  := (v_item->>'qty_ordered')::numeric;
    v_cost := (v_item->>'unit_cost')::numeric;
    v_taxp := coalesce((v_item->>'tax_pct')::numeric, 0);
    v_discp:= coalesce((v_item->>'discount_pct')::numeric, 0);
    if v_qty is null or v_qty <= 0 then raise exception 'ERR_BAD_QTY'; end if;
    if v_cost is null or v_cost < 0 then raise exception 'ERR_BAD_COST'; end if;
    v_line := round(v_qty * v_cost * (1 - v_discp/100.0), 4);
    v_line_tax := round(v_line * v_taxp/100.0, 4);
    v_subtotal := v_subtotal + v_line;
    v_tax_total := v_tax_total + v_line_tax;

    insert into purchase_order_items (po_id, product_id, variant_id, qty_ordered, unit_cost,
      unit_cost_base, tax_pct, discount_pct, line_total)
    values (v_po_id, (v_item->>'product_id')::uuid, nullif(v_item->>'variant_id','')::uuid,
      v_qty, v_cost, round(v_cost * v_rate, 4), v_taxp, v_discp, v_line);
  end loop;

  -- allocate landed cost proportional to line_total
  if v_landed > 0 and v_subtotal > 0 then
    update purchase_order_items pi
      set landed_cost_allocated = round(v_landed * (pi.line_total / v_subtotal), 4)
      where pi.po_id = v_po_id;
  end if;

  v_grand := round(v_subtotal + v_tax_total - coalesce(p_discount_total,0) + v_landed, 4);

  update purchase_orders
    set subtotal = round(v_subtotal,4), tax_total = round(v_tax_total,4), grand_total = v_grand,
        updated_at = now()
    where id = v_po_id;

  return jsonb_build_object('po_id', v_po_id, 'po_number', v_num, 'grand_total', v_grand);
end; $function$;

-- ========== RPC: update_purchase_order (DRAFT only — replaces items, recomputes) ==========
create or replace function public.update_purchase_order(
  p_po_id uuid, p_supplier_id uuid, p_expected_date date, p_currency varchar, p_exchange_rate numeric,
  p_freight numeric, p_insurance numeric, p_custom_duty numeric, p_discount_total numeric,
  p_notes text, p_items jsonb
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_rate numeric := coalesce(nullif(p_exchange_rate,0),1.0);
  v_item jsonb; v_qty numeric; v_cost numeric; v_taxp numeric; v_discp numeric;
  v_line numeric; v_line_tax numeric; v_subtotal numeric := 0; v_tax_total numeric := 0;
  v_landed numeric := coalesce(p_freight,0)+coalesce(p_insurance,0)+coalesce(p_custom_duty,0);
  v_grand numeric; v_status purchase_order_status_enum;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select status into v_status from purchase_orders where id=p_po_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_PO_NOT_FOUND'; end if;
  if v_status <> 'DRAFT' then raise exception 'ERR_PO_NOT_DRAFT'; end if;

  delete from purchase_order_items where po_id=p_po_id;
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty:=(v_item->>'qty_ordered')::numeric; v_cost:=(v_item->>'unit_cost')::numeric;
    v_taxp:=coalesce((v_item->>'tax_pct')::numeric,0); v_discp:=coalesce((v_item->>'discount_pct')::numeric,0);
    v_line:=round(v_qty*v_cost*(1-v_discp/100.0),4); v_line_tax:=round(v_line*v_taxp/100.0,4);
    v_subtotal:=v_subtotal+v_line; v_tax_total:=v_tax_total+v_line_tax;
    insert into purchase_order_items (po_id, product_id, variant_id, qty_ordered, unit_cost,
      unit_cost_base, tax_pct, discount_pct, line_total)
    values (p_po_id,(v_item->>'product_id')::uuid,nullif(v_item->>'variant_id','')::uuid,v_qty,v_cost,
      round(v_cost*v_rate,4),v_taxp,v_discp,v_line);
  end loop;
  if v_landed>0 and v_subtotal>0 then
    update purchase_order_items pi set landed_cost_allocated=round(v_landed*(pi.line_total/v_subtotal),4) where pi.po_id=p_po_id;
  end if;
  v_grand:=round(v_subtotal+v_tax_total-coalesce(p_discount_total,0)+v_landed,4);
  update purchase_orders set supplier_id=coalesce(p_supplier_id,supplier_id), expected_date=p_expected_date,
    currency=coalesce(p_currency,currency), exchange_rate=v_rate, freight_charges=coalesce(p_freight,0),
    insurance_charges=coalesce(p_insurance,0), custom_duty=coalesce(p_custom_duty,0), landed_cost=v_landed,
    discount_total=coalesce(p_discount_total,0), subtotal=round(v_subtotal,4), tax_total=round(v_tax_total,4),
    grand_total=v_grand, notes=p_notes, updated_by=v_uid, updated_at=now(), version=version+1
    where id=p_po_id;
  return jsonb_build_object('po_id',p_po_id,'grand_total',v_grand);
end; $function$;

-- ========== RPC: submit / approve / cancel ==========
create or replace function public.submit_purchase_order(p_po_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_status purchase_order_status_enum;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select status into v_status from purchase_orders where id=p_po_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_PO_NOT_FOUND'; end if;
  if v_status <> 'DRAFT' then raise exception 'ERR_BAD_TRANSITION'; end if;
  update purchase_orders set status='SUBMITTED', updated_at=now(), version=version+1 where id=p_po_id;
  return jsonb_build_object('po_id',p_po_id,'status','SUBMITTED');
end; $function$;

create or replace function public.approve_purchase_order(p_po_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid(); v_status purchase_order_status_enum;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','approve') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select status into v_status from purchase_orders where id=p_po_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_PO_NOT_FOUND'; end if;
  if v_status <> 'SUBMITTED' then raise exception 'ERR_BAD_TRANSITION'; end if;
  update purchase_orders set status='APPROVED', approved_by=v_uid, approved_at=now(), updated_at=now(), version=version+1 where id=p_po_id;
  return jsonb_build_object('po_id',p_po_id,'status','APPROVED');
end; $function$;

create or replace function public.cancel_purchase_order(p_po_id uuid, p_reason text default null)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_status purchase_order_status_enum;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','delete') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select status into v_status from purchase_orders where id=p_po_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_PO_NOT_FOUND'; end if;
  if v_status in ('RECEIVED','INVOICED','CLOSED','CANCELLED') then raise exception 'ERR_CANNOT_CANCEL'; end if;
  update purchase_orders set status='CANCELLED', notes=coalesce(p_reason,notes), updated_at=now(), version=version+1 where id=p_po_id;
  return jsonb_build_object('po_id',p_po_id,'status','CANCELLED');
end; $function$;