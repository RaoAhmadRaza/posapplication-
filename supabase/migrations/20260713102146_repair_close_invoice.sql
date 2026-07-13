-- Posting (perpetual, balanced):
--   Dr 1000 Cash   = v_paid            Dr 1100 AR = v_balance      (money split)
--   Cr 4200 Service Revenue = labour (ex-tax)
--   Cr 4000 Sales Revenue   = parts selling total (ex-tax; cost + per-job markup%)
--   Cr 2100 Output Tax      = v_tax (labour only; parts tax deferred)
--   Dr 5000 COGS / Cr 1200 Inventory = Σ repair_parts.total_cost   (CAPTURED cost — the cost-basis rule)
create or replace function public.close_repair_job(
  p_repair_id uuid, p_labour_price numeric, p_labour_tax_pct numeric, p_parts_markup jsonb,
  p_paid_amount numeric, p_warranty_days int, p_signature_url varchar
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_job repair_jobs%rowtype; v_inv uuid := gen_random_uuid(); v_num text; v_svc uuid;
  v_part record; v_part_sell numeric; v_part_sell_total numeric := 0; v_parts_cost numeric := 0;
  v_labour_tax numeric; v_parts_tax numeric := 0; v_subtotal numeric; v_tax numeric; v_grand numeric;
  v_paid numeric; v_balance numeric; v_status invoice_status_enum; v_sale_type sale_type_enum;
  v_lines jsonb := '[]'::jsonb;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('repair','update') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select * into v_job from repair_jobs where id=p_repair_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_JOB_NOT_FOUND'; end if;
  if v_job.status <> 'READY' then raise exception 'ERR_JOB_NOT_READY'; end if;   -- only READY closes

  v_svc := public.repair_service_product(v_t);
  if v_svc is null then raise exception 'ERR_SERVICE_PRODUCT_MISSING'; end if;
  v_num := public.next_number('INVOICE', v_job.branch_id);   -- repair invoice reuses the INVOICE series

  -- invoice header (direct INSERT; session_id NULL; cashier_id = the user closing the job)
  insert into invoices (id, tenant_id, branch_id, invoice_number, customer_id, cashier_id, session_id,
    status, sale_type, notes, created_by, updated_by)
  values (v_inv, v_t, v_job.branch_id, v_num, v_job.customer_id, v_uid, null,
    'DRAFT', 'CASH', 'Repair '||v_job.job_number, v_uid, v_uid);

  -- labour line → sentinel service product, no cost (profit = line_total)
  v_labour_tax := round(coalesce(p_labour_price,0) * coalesce(p_labour_tax_pct,0)/100.0, 4);
  insert into invoice_items (invoice_id, product_id, variant_id, imei_id, description, qty, unit_price,
    cost_price, discount_pct, discount_amount, tax_pct, tax_amount, line_total, profit)
  values (v_inv, v_svc, null, null, 'Repair labour — '||v_job.job_number, 1, round(coalesce(p_labour_price,0),4),
    0, 0, 0, coalesce(p_labour_tax_pct,0), v_labour_tax, round(coalesce(p_labour_price,0),4), round(coalesce(p_labour_price,0),4));

  -- parts lines: cost + per-job markup% (LOCKED). COGS basis = captured total_cost.
  for v_part in select rp.product_id, rp.qty, rp.unit_cost, rp.total_cost from repair_parts rp where rp.repair_id=p_repair_id loop
    v_part_sell := round(v_part.unit_cost * (1 + coalesce((p_parts_markup->>(v_part.product_id::text))::numeric,0)/100.0), 4);
    v_part_sell_total := v_part_sell_total + round(v_part_sell * v_part.qty, 4);
    v_parts_cost := v_parts_cost + v_part.total_cost;
    insert into invoice_items (invoice_id, product_id, variant_id, imei_id, description, qty, unit_price,
      cost_price, discount_pct, discount_amount, tax_pct, tax_amount, line_total, profit)
    values (v_inv, v_part.product_id, null, null, 'Part', v_part.qty, v_part_sell,
      v_part.unit_cost, 0, 0, 0, 0, round(v_part_sell*v_part.qty,4), round((v_part_sell-v_part.unit_cost)*v_part.qty,4));
  end loop;

  v_subtotal := round(coalesce(p_labour_price,0) + v_part_sell_total, 4);
  v_tax := round(v_labour_tax + v_parts_tax, 4);
  v_grand := round(v_subtotal + v_tax, 4);
  v_paid := round(coalesce(p_paid_amount, v_grand), 4);      -- default fully paid on pickup
  if v_paid > v_grand then raise exception 'ERR_OVERPAYMENT'; end if;
  v_balance := round(v_grand - v_paid, 4);

  -- derive VALID enum status (no 'COMPLETED' in invoice_status_enum) + sale_type from the balance
  v_status := case when v_balance <= 0 then 'PAID'::invoice_status_enum
                   when v_paid > 0     then 'PARTIALLY_PAID'::invoice_status_enum
                   else 'CONFIRMED'::invoice_status_enum end;
  v_sale_type := case when v_balance <= 0 then 'CASH'::sale_type_enum
                      when v_paid > 0     then 'MIXED'::sale_type_enum
                      else 'CREDIT'::sale_type_enum end;

  update invoices set subtotal=v_subtotal, discount_total=0, tax_total=v_tax, grand_total=v_grand,
    paid_amount=v_paid, balance=v_balance, status=v_status, sale_type=v_sale_type, updated_at=now(), updated_by=v_uid
    where id=v_inv;

  -- ===== explicit GL post (NO stock movement — parts already deducted in R3) =====
  -- lines carry account_id via acct_id(); RECONCILE the shape + post_journal arg order to the live hook.
  if v_paid > 0 then v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id', public.acct_id(v_t,'1000'), 'debit',  v_paid,  'credit', 0)); end if;
  if v_balance > 0 then v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id', public.acct_id(v_t,'1100'), 'debit',  v_balance, 'credit', 0)); end if;
  if coalesce(p_labour_price,0) > 0 then v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id', public.acct_id(v_t,'4200'), 'debit', 0, 'credit', round(p_labour_price,4))); end if;
  if v_part_sell_total > 0 then v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id', public.acct_id(v_t,'4000'), 'debit', 0, 'credit', v_part_sell_total)); end if;
  if v_tax > 0 then v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_id', public.acct_id(v_t,'2100'), 'debit', 0, 'credit', v_tax)); end if;
  if v_parts_cost > 0 then
    v_lines := v_lines || jsonb_build_array(
      jsonb_build_object('account_id', public.acct_id(v_t,'5000'), 'debit',  v_parts_cost, 'credit', 0),
      jsonb_build_object('account_id', public.acct_id(v_t,'1200'), 'debit', 0, 'credit', v_parts_cost));
  end if;
  perform public.post_journal(v_job.branch_id, 'REPAIR_INVOICE', v_inv, 'Repair '||v_job.job_number,
    v_lines, current_date, null, false);

  -- move job to DELIVERED + link invoice + warranty + history
  update repair_jobs set status='DELIVERED', invoice_id=v_inv, final_cost=v_grand, delivered_at=now(),
    customer_signature_url=coalesce(p_signature_url, customer_signature_url),
    warranty_expires_at=case when p_warranty_days is not null then current_date + p_warranty_days else warranty_expires_at end,
    updated_by=v_uid, updated_at=now(), version=version+1
    where id=p_repair_id;
  insert into repair_status_history (repair_id, old_status, new_status, changed_by, notes)
  values (p_repair_id, 'READY', 'DELIVERED', v_uid, 'Delivered + invoiced '||v_num);

  return jsonb_build_object('repair_id', p_repair_id, 'invoice_id', v_inv, 'invoice_number', v_num,
    'grand_total', v_grand, 'status', 'DELIVERED');
end; $function$;