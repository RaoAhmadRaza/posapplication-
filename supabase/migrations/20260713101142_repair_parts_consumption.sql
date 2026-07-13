-- add_repair_part: consume a stock part into a repair. Deducts canonical stock (REPAIR_USE, negative qty,
-- warehouse_id NULL), stores the returned stock_ledger_id + captured cost. Gated repair:update; the inner
-- post_stock_movement now accepts REPAIR_USE on repair perms (File 1). avg_cost read is product-level at
-- canonical NULL warehouse (mirrors create_sale; canonical uq index is per (tenant,branch,product) → one row).
-- variant_id still flows to post_stock_movement ARG4.
create or replace function public.add_repair_part(p_repair_id uuid, p_product_id uuid, p_variant_id uuid, p_qty numeric, p_notes text)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_branch uuid; v_status repair_status_enum; v_cost numeric; v_ledger uuid; v_part uuid;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('repair','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if p_qty is null or p_qty <= 0 then raise exception 'ERR_BAD_QTY'; end if;
  select branch_id, status into v_branch, v_status from repair_jobs where id=p_repair_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_JOB_NOT_FOUND'; end if;
  if v_status in ('DELIVERED','CANCELLED') then raise exception 'ERR_JOB_CLOSED'; end if;

  -- current avg cost at canonical location (warehouse_id NULL), product-level
  select avg_cost into v_cost from stock_balance
    where tenant_id=v_t and branch_id=v_branch and product_id=p_product_id and warehouse_id is null;
  v_cost := coalesce(v_cost, 0);

  -- deduct stock (negative). post_stock_movement guards negative balance + enforces the (now repair-aware) gate.
  perform public.post_stock_movement(v_branch, null, p_product_id, p_variant_id,
    'REPAIR_USE'::stock_movement_type_enum, -p_qty, v_cost, 'REPAIR', p_repair_id, 'Repair part');

  -- ledger row just written (most recent for this ref/product)
  select id into v_ledger from stock_ledger
    where tenant_id=v_t and reference_type='REPAIR' and reference_id=p_repair_id and product_id=p_product_id
    order by created_at desc limit 1;

  insert into repair_parts (repair_id, product_id, qty, unit_cost, total_cost, stock_ledger_id, notes, created_by)
  values (p_repair_id, p_product_id, p_qty, round(v_cost,4), round(v_cost*p_qty,4), v_ledger, p_notes, v_uid)
  returning id into v_part;

  return jsonb_build_object('repair_part_id', v_part, 'unit_cost', round(v_cost,4), 'total_cost', round(v_cost*p_qty,4));
end; $function$;

-- remove_repair_part: restock + delete before job close. Reverses the movement (positive qty).
create or replace function public.remove_repair_part(p_repair_part_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_branch uuid; v_prod uuid; v_qty numeric; v_cost numeric; v_repair uuid; v_status repair_status_enum;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('repair','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select rp.repair_id, rp.product_id, rp.qty, rp.unit_cost into v_repair, v_prod, v_qty, v_cost
    from repair_parts rp join repair_jobs j on j.id=rp.repair_id
    where rp.id=p_repair_part_id and j.tenant_id=v_t;
  if not found then raise exception 'ERR_PART_NOT_FOUND'; end if;
  select branch_id, status into v_branch, v_status from repair_jobs where id=v_repair;
  if v_status in ('DELIVERED','CANCELLED') then raise exception 'ERR_JOB_CLOSED'; end if;
  perform public.post_stock_movement(v_branch, null, v_prod, null, 'REPAIR_USE'::stock_movement_type_enum,
    v_qty, v_cost, 'REPAIR_REVERSAL', v_repair, 'Repair part removed');
  delete from repair_parts where id=p_repair_part_id;
  return jsonb_build_object('removed', p_repair_part_id);
end; $function$;
