-- ========== M07 A5 (slice 1): auto-post SALES + customer payments to the GL ==========
-- Wires the journal engine (post_journal) into the sales money funnel so the ledger
-- reflects revenue, tax, AR and COGS. GL mirrors the AR subledger 1:1 (invoices.balance).
-- Auto-posts are ungated system posts (post_journal p_gate=false) — a CASHIER without
-- accounting:create must still be able to complete a sale.
--
-- Scope of this slice: create_sale + new record_customer_payment. Purchase-side
-- auto-post (GRN / purchase invoice / supplier payment / purchase return) and
-- sales-return GL are the next slice.

-- Idempotency guard: one journal per source document (per type). Prevents an
-- accidental double-post of the same row. WHERE reference_id is not null keeps
-- manual vouchers/expenses (which may post with a null reference) out of scope.
create unique index if not exists uq_journal_entries_reference
  on public.journal_entries (tenant_id, reference_type, reference_id)
  where reference_id is not null;

-- ========== create_sale — verbatim + GL auto-post block before RETURN ==========
CREATE OR REPLACE FUNCTION public.create_sale(p_branch_id uuid, p_customer_id uuid, p_items jsonb, p_payments jsonb, p_notes text DEFAULT NULL::text, p_session_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid(); v_session uuid;
  v_invoice uuid := gen_random_uuid(); v_number varchar; r jsonb;
  v_pid uuid; v_qty numeric; v_unit numeric; v_dp numeric; v_tp numeric; v_imei uuid; v_variant uuid; v_desc text;
  v_ptype product_type_enum; v_min numeric; v_cost numeric; v_da numeric; v_taxable numeric; v_ta numeric; v_line numeric; v_profit numeric;
  v_subtotal numeric:=0; v_disc numeric:=0; v_tax numeric:=0; v_grand numeric:=0;
  v_paid numeric:=0; v_change numeric; v_applied numeric; v_balance numeric; v_methods int:=0;
  v_status invoice_status_enum; v_sale_type sale_type_enum;
  v_climit numeric; v_outstanding numeric;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('sales','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not public.auth_has_branch(p_branch_id) then raise exception 'ERR_BRANCH_NOT_ASSIGNED' using errcode='42501'; end if;
  if p_items is null or jsonb_array_length(p_items)=0 then raise exception 'ERR_EMPTY_CART'; end if;

  if p_session_id is not null then
    select id into v_session from cashier_sessions where id=p_session_id and tenant_id=v_t and status='OPEN';
  else
    select id into v_session from cashier_sessions
      where tenant_id=v_t and branch_id=p_branch_id and cashier_id=v_uid and status='OPEN'
      order by opened_at desc limit 1;
  end if;
  if v_session is null then raise exception 'ERR_NO_OPEN_SESSION'; end if;

  v_number := public.next_number('INVOICE'::number_series_type_enum, p_branch_id);

  insert into invoices (id, tenant_id, branch_id, invoice_number, customer_id, cashier_id, session_id,
                        status, sale_type, notes, created_by, updated_by)
  values (v_invoice, v_t, p_branch_id, v_number, p_customer_id, v_uid, v_session, 'DRAFT', 'CASH', p_notes, v_uid, v_uid);

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

    select type, min_selling_price into v_ptype, v_min
      from products where id=v_pid and tenant_id=v_t and deleted_at is null;
    if not found then raise exception 'ERR_PRODUCT_NOT_FOUND: %', v_pid; end if;
    if v_ptype='SERIALIZED' then
      if v_imei is null then raise exception 'ERR_IMEI_REQUIRED: %', v_pid; end if;
      if v_qty <> 1 then raise exception 'ERR_SERIALIZED_QTY_ONE: %', v_pid; end if;
    end if;

    -- R3: enforce minimum selling price (managers with sales:approve may override)
    if v_min is not null and v_min > 0 and v_unit < v_min
       and not public.auth_has_permission('sales','approve') then
      raise exception 'ERR_BELOW_MIN_PRICE: % (min %, got %)', v_pid, v_min, v_unit;
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
    -- ===== R4 credit-limit guard (OPTIONAL — delete this whole block to DEFER credit-limit) =====
    select coalesce(credit_limit,0) into v_climit from customers where id=p_customer_id and tenant_id=v_t;
    if v_climit > 0 and not public.auth_has_permission('sales','approve') then
      select coalesce(sum(balance),0) into v_outstanding from invoices
        where tenant_id=v_t and customer_id=p_customer_id
          and status in ('CONFIRMED','PARTIALLY_PAID') and deleted_at is null;
      if (v_outstanding + v_balance) > v_climit then
        raise exception 'ERR_CREDIT_LIMIT_EXCEEDED: limit % outstanding % new %', v_climit, v_outstanding, v_balance;
      end if;
    end if;
    -- ===== end R4 block =====
    v_sale_type := 'CREDIT';
  elsif v_methods > 1 then v_sale_type := 'MIXED';
  else v_sale_type := 'CASH'; end if;

  update invoices set subtotal=v_subtotal, discount_total=v_disc, tax_total=v_tax, grand_total=v_grand,
    paid_amount=v_applied, balance=v_balance, change_amount=v_change, status=v_status, sale_type=v_sale_type,
    updated_at=now(), updated_by=v_uid
  where id=v_invoice;

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
    if v_imei is not null then
      update imei_records set status='SOLD', sold_invoice_id=v_invoice
        where id=v_imei and tenant_id=v_t and status='AVAILABLE';
      if not found then raise exception 'ERR_IMEI_NOT_AVAILABLE: %', v_imei; end if;
    end if;
  end loop;

  -- ===== M07 A5: auto-post sale to GL (ungated system post; mirrors AR subledger) =====
  -- Dr Cash(applied) + Dr AR(balance) = Cr Revenue(subtotal-disc) + Cr OutputTax(tax); plus Dr COGS / Cr Inventory.
  -- ponytail: all paid amounts book to Cash 1000 — bank/card split by payment method deferred.
  declare
    v_cogs numeric; v_rev numeric := v_subtotal - v_disc; v_lines jsonb := '[]'::jsonb;
  begin
    select coalesce(sum(cost_price*qty),0) into v_cogs from invoice_items where invoice_id=v_invoice;
    if v_applied > 0 then v_lines := v_lines || jsonb_build_object('account_code','1000','debit',v_applied); end if;
    if v_balance > 0 then v_lines := v_lines || jsonb_build_object('account_code','1100','debit',v_balance); end if;
    if v_rev     > 0 then v_lines := v_lines || jsonb_build_object('account_code','4000','credit',v_rev); end if;
    if v_tax     > 0 then v_lines := v_lines || jsonb_build_object('account_code','2100','credit',v_tax); end if;
    if v_cogs    > 0 then v_lines := v_lines
        || jsonb_build_object('account_code','5000','debit',v_cogs)
        || jsonb_build_object('account_code','1200','credit',v_cogs); end if;
    if jsonb_array_length(v_lines) >= 2 then
      perform public.post_journal(p_branch_id, 'SALE', v_invoice, 'POS sale '||v_number, v_lines, current_date, v_invoice, false);
    end if;
  end;

  return jsonb_build_object('invoice_id',v_invoice,'invoice_number',v_number,'grand_total',v_grand,
    'paid_amount',v_applied,'balance',v_balance,'change_amount',v_change,'status',v_status);
end; $function$;

-- ========== record_customer_payment — credit settlement + GL (mirrors record_supplier_payment) ==========
create or replace function public.record_customer_payment(
  p_customer_id uuid, p_invoice_id uuid, p_method payment_method_enum,
  p_amount numeric, p_reference varchar, p_bank_account_id uuid, p_notes text)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_branch uuid; v_bal numeric; v_pay_id uuid; v_new_bal numeric;
  v_status invoice_status_enum; v_debit_code varchar;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('sales','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'ERR_BAD_AMOUNT'; end if;

  select branch_id, balance into v_branch, v_bal from invoices
    where id=p_invoice_id and tenant_id=v_t and customer_id=p_customer_id and deleted_at is null;
  if not found then raise exception 'ERR_INVOICE_NOT_FOUND'; end if;
  if p_amount > v_bal then raise exception 'ERR_OVERPAYMENT'; end if;

  insert into payments (tenant_id, invoice_id, method, amount, reference, bank_account_id, notes, created_by)
  values (v_t, p_invoice_id, p_method, round(p_amount,4), nullif(p_reference,''), p_bank_account_id, p_notes, v_uid)
  returning id into v_pay_id;

  v_new_bal := round(v_bal - p_amount, 4);
  v_status := case when v_new_bal <= 0 then 'PAID' else 'PARTIALLY_PAID' end;
  update invoices set paid_amount = paid_amount + round(p_amount,4), balance = v_new_bal,
    status = v_status, updated_at = now(), version = version + 1, updated_by = v_uid
    where id = p_invoice_id;

  -- GL: Dr Cash/Bank, Cr AR (mirrors the invoice balance reduction; ungated system post)
  v_debit_code := case when p_bank_account_id is not null then '1010' else '1000' end;
  perform public.post_journal(v_branch, 'CUSTOMER_PAYMENT', v_pay_id, 'Customer payment', jsonb_build_array(
    jsonb_build_object('account_code', v_debit_code, 'debit', round(p_amount,4)),
    jsonb_build_object('account_code', '1100', 'credit', round(p_amount,4))),
    current_date, v_pay_id, false);

  return jsonb_build_object('payment_id', v_pay_id, 'balance', v_new_bal, 'status', v_status);
end; $function$;

grant execute on function public.record_customer_payment(uuid,uuid,payment_method_enum,numeric,varchar,uuid,text) to authenticated;
