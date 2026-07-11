-- post_stock_movement_operation_aware.sql
-- R1: make the engine permission gate operation-aware so CASHIER (sales:create) can sell.
-- ONLY the permission-gate block changed vs the live function; everything else is identical.
-- SALE / RETURN_IN  -> require sales:create OR sales:update  (POS sales + customer returns)
-- everything else   -> require inventory:update              (purchases, transfers, adjustments,
--                                                             scrap, opening balance, RETURN_OUT to supplier)
CREATE OR REPLACE FUNCTION public.post_stock_movement(p_branch_id uuid, p_warehouse_id uuid, p_product_id uuid, p_variant_id uuid, p_operation_type stock_movement_type_enum, p_qty_change numeric, p_cost_per_unit numeric DEFAULT 0, p_reference_type text DEFAULT 'OPENING'::text, p_reference_id uuid DEFAULT NULL::uuid, p_notes text DEFAULT NULL::text)
 RETURNS stock_balance
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_tenant uuid := public.auth_tenant_id();
  v_uid    uuid := auth.uid();
  v_bal    public.stock_balance;
begin
  if v_tenant is null then raise exception 'no tenant' using errcode='42501'; end if;

  -- operation-aware permission gate (R1)
  if p_operation_type in ('SALE','RETURN_IN') then
    if not (public.auth_has_permission('sales','create') or public.auth_has_permission('sales','update')) then
      raise exception 'permission denied' using errcode='42501';
    end if;
  else
    if not public.auth_has_permission('inventory','update') then
      raise exception 'permission denied' using errcode='42501';
    end if;
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
end; $function$