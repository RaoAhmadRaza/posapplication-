-- ========== ENUM ==========
do $$ begin
  create type purchase_return_status_enum as enum ('DRAFT','CONFIRMED','CANCELLED');
exception when duplicate_object then null; end $$;

-- ========== TABLES (styled to match §3.6 purchase tables) ==========
create table if not exists public.purchase_returns (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid not null references public.branches(id),
  supplier_id uuid not null references public.suppliers(id),
  po_id uuid not null references public.purchase_orders(id),
  grn_id uuid references public.grns(id),
  invoice_id uuid references public.purchase_invoices(id),
  return_number varchar(50) not null,
  status purchase_return_status_enum not null default 'CONFIRMED',
  reason text,
  return_date date not null default current_date,
  subtotal decimal(15,4) not null default 0,
  tax_total decimal(15,4) not null default 0,
  total_amount decimal(15,4) not null default 0,
  notes text,
  correlation_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  version integer not null default 1,
  created_by uuid references public.users(id),
  updated_by uuid references public.users(id)
);
create unique index if not exists uq_pr_tenant_number on public.purchase_returns(tenant_id, return_number) where deleted_at is null;
create index if not exists idx_pr_po        on public.purchase_returns(po_id) where deleted_at is null;
create index if not exists idx_pr_supplier  on public.purchase_returns(supplier_id, return_date) where deleted_at is null;
create index if not exists idx_pr_status    on public.purchase_returns(tenant_id, status) where deleted_at is null;

create table if not exists public.purchase_return_items (
  id uuid primary key default gen_random_uuid(),
  return_id uuid not null references public.purchase_returns(id) on delete cascade,
  po_item_id uuid not null references public.purchase_order_items(id),
  product_id uuid not null references public.products(id),
  variant_id uuid references public.product_variants(id),
  qty_returned decimal(15,4) not null,
  unit_cost decimal(15,4) not null,
  tax_pct decimal(5,2) not null default 0,
  line_total decimal(15,4) not null,
  imei_ids_json jsonb,
  created_at timestamptz not null default now()
);
create index if not exists idx_pr_items_return  on public.purchase_return_items(return_id);
create index if not exists idx_pr_items_po_item on public.purchase_return_items(po_item_id);
create index if not exists idx_pr_items_product on public.purchase_return_items(product_id);
do $$ begin
  alter table public.purchase_return_items add constraint chk_pr_items_qty check (qty_returned > 0);
exception when duplicate_object then null; end $$;

-- ========== RLS: client read tenant rows; writes via RPC ==========
alter table public.purchase_returns enable row level security;
drop policy if exists "pr tenant read" on public.purchase_returns;
create policy "pr tenant read" on public.purchase_returns
  for select to authenticated using (tenant_id = public.auth_tenant_id());
revoke insert, update, delete on public.purchase_returns from authenticated;

alter table public.purchase_return_items enable row level security;
drop policy if exists "pr_items tenant read" on public.purchase_return_items;
create policy "pr_items tenant read" on public.purchase_return_items
  for select to authenticated using (
    exists (select 1 from public.purchase_returns pr where pr.id = return_id and pr.tenant_id = public.auth_tenant_id()));
revoke insert, update, delete on public.purchase_return_items from authenticated;

-- ========== NUMBER SERIES SEED (PR-) for all tenants ==========
insert into public.number_series (tenant_id, branch_id, type, prefix, current_number)
select t.id, null, 'PURCHASE_RETURN'::number_series_type_enum, 'PR-', 0
from public.tenants t
where not exists (
  select 1 from public.number_series ns
  where ns.tenant_id = t.id and ns.type = 'PURCHASE_RETURN'::number_series_type_enum and ns.branch_id is null
);

-- ========== RPC: create_purchase_return (atomic) ==========
-- p_items jsonb array of {po_item_id, qty_returned, imei_ids?[]}
-- Gate purchase:update; inner post_stock_movement(RETURN_OUT) enforces inventory:update.
-- Stock reverses at canonical warehouse_id = NULL. Validates qty against (received − prior returns).
-- Does NOT mutate po_items/PO/invoice unless p_reduce_invoice = true (opt-in).
create or replace function public.create_purchase_return(
  p_branch_id uuid,
  p_po_id uuid,
  p_grn_id uuid,
  p_invoice_id uuid,
  p_reason text,
  p_notes text,
  p_items jsonb,
  p_reduce_invoice boolean default false
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_supplier uuid; v_po_branch uuid; v_ret_id uuid; v_num text;
  v_item jsonb; v_po_item purchase_order_items%rowtype;
  v_qty numeric; v_already numeric; v_avail numeric;
  v_line numeric; v_line_tax numeric; v_landed_unit numeric; v_cost_unit numeric;
  v_subtotal numeric := 0; v_tax_total numeric := 0; v_total numeric;
  v_imei text; v_imei_count int;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not public.auth_has_branch(p_branch_id) then raise exception 'ERR_BRANCH_NOT_ASSIGNED' using errcode='42501'; end if;

  select supplier_id, branch_id into v_supplier, v_po_branch
    from purchase_orders where id=p_po_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_PO_NOT_FOUND'; end if;
  if p_grn_id is not null and not exists (select 1 from grns where id=p_grn_id and po_id=p_po_id and tenant_id=v_t) then
    raise exception 'ERR_GRN_MISMATCH'; end if;
  if p_invoice_id is not null and not exists (select 1 from purchase_invoices where id=p_invoice_id and po_id=p_po_id and tenant_id=v_t and deleted_at is null) then
    raise exception 'ERR_INVOICE_MISMATCH'; end if;
  if p_items is null or jsonb_array_length(p_items)=0 then raise exception 'ERR_NO_ITEMS'; end if;

  v_num := public.next_number('PURCHASE_RETURN', p_branch_id);

  insert into purchase_returns (tenant_id, branch_id, supplier_id, po_id, grn_id, invoice_id,
    return_number, status, reason, notes, created_by, updated_by)
  values (v_t, p_branch_id, v_supplier, p_po_id, p_grn_id, p_invoice_id, v_num, 'CONFIRMED',
    p_reason, p_notes, v_uid, v_uid)
  returning id into v_ret_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    select * into v_po_item from purchase_order_items
      where id=(v_item->>'po_item_id')::uuid and po_id=p_po_id;
    if not found then raise exception 'ERR_PO_ITEM_NOT_FOUND'; end if;

    v_qty := (v_item->>'qty_returned')::numeric;
    if v_qty is null or v_qty <= 0 then raise exception 'ERR_BAD_QTY'; end if;

    -- available = received − prior CONFIRMED returns for this po_item
    select coalesce(sum(pri.qty_returned),0) into v_already
      from purchase_return_items pri
      join purchase_returns pr on pr.id=pri.return_id
      where pri.po_item_id=v_po_item.id and pr.status='CONFIRMED' and pr.deleted_at is null;
    v_avail := v_po_item.qty_received - v_already;
    if v_qty > v_avail then raise exception 'ERR_RETURN_EXCEEDS_RECEIVED'; end if;

    -- IMEI: if serials supplied, count must equal qty; they must be currently sellable + this product
    if (v_item ? 'imei_ids') and jsonb_typeof(v_item->'imei_ids')='array' then
      v_imei_count := jsonb_array_length(v_item->'imei_ids');
      if v_imei_count <> v_qty then raise exception 'ERR_IMEI_COUNT_MISMATCH'; end if;
      for v_imei in select jsonb_array_elements_text(v_item->'imei_ids') loop
        update imei_records
          set status = 'RETURNED'::imei_status_enum,   -- <<< R0.4 confirm this label >>>
              updated_at = now(), version = version + 1
          where tenant_id=v_t and product_id=v_po_item.product_id and imei=trim(v_imei);
        if not found then raise exception 'ERR_IMEI_NOT_FOUND'; end if;
      end loop;
    end if;

    v_line := round(v_qty * v_po_item.unit_cost, 4);
    v_line_tax := round(v_line * v_po_item.tax_pct/100.0, 4);
    v_subtotal := v_subtotal + v_line;
    v_tax_total := v_tax_total + v_line_tax;

    insert into purchase_return_items (return_id, po_item_id, product_id, variant_id, qty_returned,
      unit_cost, tax_pct, line_total, imei_ids_json)
    values (v_ret_id, v_po_item.id, v_po_item.product_id, v_po_item.variant_id, v_qty,
      v_po_item.unit_cost, v_po_item.tax_pct, v_line, v_item->'imei_ids');

    -- reverse stock: canonical NULL warehouse, RETURN_OUT, NEGATIVE qty, at landed unit cost
    v_landed_unit := case when v_po_item.qty_ordered > 0
      then v_po_item.landed_cost_allocated / v_po_item.qty_ordered else 0 end;
    v_cost_unit := round(v_po_item.unit_cost_base + v_landed_unit, 4);
    perform public.post_stock_movement(
      p_branch_id, null, v_po_item.product_id, v_po_item.variant_id,
      'RETURN_OUT'::stock_movement_type_enum, -v_qty, v_cost_unit,
      'PURCHASE_RETURN', v_ret_id, 'Return '||v_num);
  end loop;

  v_total := round(v_subtotal + v_tax_total, 4);
  update purchase_returns set subtotal=round(v_subtotal,4), tax_total=round(v_tax_total,4),
    total_amount=v_total, updated_at=now() where id=v_ret_id;

  -- OPT-IN only: reduce a linked invoice's outstanding balance (true debit-note-against-bill)
  if p_reduce_invoice and p_invoice_id is not null then
    update purchase_invoices
      set balance = greatest(0, balance - v_total), updated_at = now(), version = version + 1
      where id = p_invoice_id;
  end if;

  return jsonb_build_object('return_id', v_ret_id, 'return_number', v_num, 'total_amount', v_total);
end; $function$;

-- ========== supplier_ledger: net returns as CREDITS (payable down) ==========
-- Full replacement of the Phase-5 read RPC, adding a RETURN credit branch. No table mutation.
create or replace function public.supplier_ledger(p_supplier_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_opening numeric; v_result jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','read') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select opening_balance into v_opening from suppliers where id=p_supplier_id and tenant_id=v_t;
  if not found then raise exception 'ERR_SUPPLIER_NOT_FOUND'; end if;

  with entries as (
    select pi.created_at as ts, 'INVOICE' as kind, pi.total_amount as debit, 0::numeric as credit,
           pi.supplier_invoice_number as ref, pi.status::text as status
    from purchase_invoices pi where pi.supplier_id=p_supplier_id and pi.tenant_id=v_t and pi.deleted_at is null
    union all
    select sp.paid_at, 'PAYMENT', 0, sp.amount, sp.voucher_number, sp.method::text
    from supplier_payments sp where sp.supplier_id=p_supplier_id and sp.tenant_id=v_t
    union all
    select pr.created_at, 'RETURN', 0, pr.total_amount, pr.return_number, pr.status::text
    from purchase_returns pr where pr.supplier_id=p_supplier_id and pr.tenant_id=v_t
      and pr.deleted_at is null and pr.status='CONFIRMED'
  ), ordered as (
    select *, sum(debit - credit) over (order by ts, kind rows between unbounded preceding and current row) as running
    from entries
  )
  select jsonb_build_object(
    'supplier_id', p_supplier_id,
    'opening_balance', coalesce(v_opening,0),
    'current_balance', coalesce(v_opening,0) + coalesce((select sum(debit-credit) from entries),0),
    'entries', coalesce((select jsonb_agg(jsonb_build_object(
        'ts',ts,'kind',kind,'debit',debit,'credit',credit,'reference',ref,'status',status,
        'running_balance', coalesce(v_opening,0) + running) order by ts, kind) from ordered), '[]'::jsonb)
  ) into v_result;
  return v_result;
end; $function$;