-- ========== TABLES (verbatim §3.6) ==========
create table if not exists public.grns (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  po_id uuid not null references public.purchase_orders(id),
  grn_number varchar(50) not null,
  warehouse_id uuid references public.warehouses(id),   -- metadata only; stock posts canonical NULL
  received_by uuid not null references public.users(id),
  received_at timestamptz not null default now(),
  notes text,
  correlation_id uuid,
  created_at timestamptz not null default now()
);
create unique index if not exists uq_grns_tenant_number on public.grns(tenant_id, grn_number);
create index if not exists idx_grns_po on public.grns(po_id);
create index if not exists idx_grns_tenant_created on public.grns(tenant_id, created_at);

create table if not exists public.grn_items (
  id uuid primary key default gen_random_uuid(),
  grn_id uuid not null references public.grns(id) on delete cascade,
  po_item_id uuid not null references public.purchase_order_items(id),
  product_id uuid not null references public.products(id),
  qty_received decimal(15,4) not null,
  qty_rejected decimal(15,4) not null default 0,
  imei_ids_json jsonb,
  batch_number varchar(100),
  expiry_date date,
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists idx_grn_items_grn     on public.grn_items(grn_id);
create index if not exists idx_grn_items_po_item on public.grn_items(po_item_id);
create index if not exists idx_grn_items_product on public.grn_items(product_id);
do $$ begin
  alter table public.grn_items add constraint chk_grn_items_qty check (qty_received > 0);
exception when duplicate_object then null; end $$;

-- ========== RLS: client read tenant rows; writes via RPC; GRN immutable ==========
alter table public.grns enable row level security;
drop policy if exists "grns tenant read" on public.grns;
create policy "grns tenant read" on public.grns
  for select to authenticated using (tenant_id = public.auth_tenant_id());
revoke insert, update, delete on public.grns from authenticated;

alter table public.grn_items enable row level security;
drop policy if exists "grn_items tenant read" on public.grn_items;
create policy "grn_items tenant read" on public.grn_items
  for select to authenticated using (
    exists (select 1 from public.grns g where g.id = grn_id and g.tenant_id = public.auth_tenant_id()));
revoke insert, update, delete on public.grn_items from authenticated;

-- ========== RPC: receive_goods ==========
-- p_items jsonb array of {po_item_id, qty_received, qty_rejected?, imei_ids?[], batch_number?, expiry_date?}
-- Gated purchase:update; inner post_stock_movement(PURCHASE_RECEIPT) also enforces inventory:update.
-- Stock ALWAYS posts to canonical warehouse_id = NULL (no non-canonical split). grns.warehouse_id kept NULL.
create or replace function public.receive_goods(
  p_po_id uuid,
  p_notes text,
  p_items jsonb
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_branch uuid; v_status purchase_order_status_enum; v_grn_id uuid; v_num text;
  v_item jsonb; v_po_item purchase_order_items%rowtype;
  v_qty numeric; v_rej numeric; v_landed_unit numeric; v_cost_unit numeric;
  v_imei text; v_serialized boolean; v_all_received boolean;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;

  select branch_id, status into v_branch, v_status
    from purchase_orders where id=p_po_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_PO_NOT_FOUND'; end if;
  if v_status not in ('APPROVED','PARTIALLY_RECEIVED') then raise exception 'ERR_PO_NOT_RECEIVABLE'; end if;
  if p_items is null or jsonb_array_length(p_items)=0 then raise exception 'ERR_NO_ITEMS'; end if;

  v_num := public.next_number('GRN', v_branch);
  insert into grns (tenant_id, po_id, grn_number, warehouse_id, received_by, notes)
  values (v_t, p_po_id, v_num, null, v_uid, p_notes)     -- warehouse_id NULL: canonical
  returning id into v_grn_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_po_item from purchase_order_items
      where id=(v_item->>'po_item_id')::uuid and po_id=p_po_id;
    if not found then raise exception 'ERR_PO_ITEM_NOT_FOUND'; end if;

    v_qty := (v_item->>'qty_received')::numeric;
    v_rej := coalesce((v_item->>'qty_rejected')::numeric, 0);
    if v_qty is null or v_qty <= 0 then raise exception 'ERR_BAD_QTY'; end if;
    if v_po_item.qty_received + v_qty > v_po_item.qty_ordered then
      raise exception 'ERR_OVER_RECEIPT';    -- would exceed ordered qty
    end if;

    insert into grn_items (grn_id, po_item_id, product_id, qty_received, qty_rejected,
      imei_ids_json, batch_number, expiry_date, notes)
    values (v_grn_id, v_po_item.id, v_po_item.product_id, v_qty, v_rej,
      v_item->'imei_ids', nullif(v_item->>'batch_number',''), nullif(v_item->>'expiry_date','')::date,
      nullif(v_item->>'notes',''));

    update purchase_order_items set qty_received = qty_received + v_qty where id = v_po_item.id;

    -- landed unit cost = base cost + allocated landed cost per ordered unit
    v_landed_unit := case when v_po_item.qty_ordered > 0
      then v_po_item.landed_cost_allocated / v_po_item.qty_ordered else 0 end;
    v_cost_unit := round(v_po_item.unit_cost_base + v_landed_unit, 4);

    -- STOCK: canonical NULL warehouse, PURCHASE_RECEIPT, positive qty
    perform public.post_stock_movement(
      v_branch, null, v_po_item.product_id, v_po_item.variant_id,
      'PURCHASE_RECEIPT'::stock_movement_type_enum, v_qty, v_cost_unit,
      'GRN', v_grn_id, 'GRN '||v_num);

    -- IMEI capture for serialized products (imei_ids present) -> imei_records IN_STOCK
    -- Reconciled to P0.7: source_type, cost_price, status, branch_id are NOT NULL (no defaults);
    -- source_id, warehouse_id nullable. warehouse_id NULL = canonical, consistent with the stock post.
    if (v_item ? 'imei_ids') and jsonb_typeof(v_item->'imei_ids')='array' then
      for v_imei in select jsonb_array_elements_text(v_item->'imei_ids') loop
        if length(trim(v_imei)) > 0 then
          insert into imei_records (tenant_id, product_id, variant_id, imei, status, branch_id,
            warehouse_id, source_type, source_id, cost_price)
          values (v_t, v_po_item.product_id, v_po_item.variant_id, trim(v_imei),
            'IN_STOCK'::imei_status_enum, v_branch, null, 'GRN', v_grn_id, v_cost_unit)
          on conflict do nothing;
        end if;
      end loop;
    end if;
  end loop;

  -- advance PO status
  select bool_and(qty_received >= qty_ordered) into v_all_received
    from purchase_order_items where po_id = p_po_id;
  update purchase_orders
    set status = case when v_all_received then 'RECEIVED' else 'PARTIALLY_RECEIVED' end,
        updated_at = now(), version = version + 1
    where id = p_po_id;

  return jsonb_build_object('grn_id', v_grn_id, 'grn_number', v_num,
    'po_status', case when v_all_received then 'RECEIVED' else 'PARTIALLY_RECEIVED' end);
end; $function$;