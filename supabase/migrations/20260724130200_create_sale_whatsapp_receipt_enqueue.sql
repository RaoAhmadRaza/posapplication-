-- WhatsApp PDF receipt, part 3/6: enqueue a receipt row at the end of create_sale.
--
-- Body is BYTE-IDENTICAL to the authoritative definition (20260716183219_create_sale_authoritative_tax)
-- except for ONE added block: a best-effort communication_logs enqueue placed AFTER the GL auto-post
-- and BEFORE the final return. It fires once per invoice — the idempotent replay guard (top of the
-- function) early-returns before ever reaching here, so offline-sync replays never re-enqueue.
--
-- The enqueue is its OWN sub-block that swallows ALL exceptions (including unique_violation). This is
-- load-bearing: the function's outer `when unique_violation` handler treats that error as an
-- idempotency race and returns the "winner" invoice — if an enqueue conflict bubbled up to it, a
-- legitimately new sale would return a wrong result. So the enqueue must never let anything escape.
-- It also uses ON CONFLICT DO NOTHING against uq_comm_sale_receipt as first-line dedupe.
--
-- Only enqueues when the sale has a customer WITH a non-empty phone (walk-in / no-phone → the SELECT
-- yields no row → nothing enqueued). Media (the PDF) is attached later by the receipt-sender edge fn.

drop function if exists public.create_sale(uuid, uuid, jsonb, jsonb, text, uuid, uuid);
create function public.create_sale(
  p_branch_id uuid, p_customer_id uuid, p_items jsonb, p_payments jsonb,
  p_notes text default null, p_session_id uuid default null, p_idempotency_key uuid default null
) returns jsonb language plpgsql security definer set search_path to 'public' as $$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid(); v_session uuid;
  v_invoice uuid := gen_random_uuid(); v_number varchar; r jsonb;
  v_pid uuid; v_qty numeric; v_unit numeric; v_dp numeric; v_tp numeric; v_imei uuid; v_variant uuid; v_desc text;
  v_ptype product_type_enum; v_min numeric; v_cost numeric; v_da numeric; v_taxable numeric; v_ta numeric; v_line numeric; v_profit numeric;
  v_subtotal numeric:=0; v_disc numeric:=0; v_tax numeric:=0; v_grand numeric:=0;
  v_paid numeric:=0; v_change numeric; v_applied numeric; v_balance numeric; v_methods int:=0;
  v_status invoice_status_enum; v_sale_type sale_type_enum;
  v_climit numeric; v_outstanding numeric;
  v_existing_invoice_id uuid;
  v_tax_rate numeric; v_tax_mode tax_calculation_mode_enum;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('sales','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if not public.auth_has_branch(p_branch_id) then raise exception 'ERR_BRANCH_NOT_ASSIGNED' using errcode='42501'; end if;

  -- === IDEMPOTENT REPLAY GUARD ==========================================
  -- A replay is a duplicate DELIVERY, not a duplicate SALE. Return the original result; never raise.
  -- ⚠️ Placement is load-bearing (fact #5): next_number is a gap-free FOR UPDATE counter. A guard AFTER it
  -- would BURN a document number on every replay and gap the sequence — spending the exact property
  -- sign-off #1 protects, as an accident of an unrelated feature. It sits here, BEFORE next_number.
  if p_idempotency_key is not null then
    select i.id into v_existing_invoice_id from invoices i
     where i.tenant_id = v_t and i.idempotency_key = p_idempotency_key;
    if found then
      return (select jsonb_build_object('invoice_id',i.id,'invoice_number',i.invoice_number,'grand_total',i.grand_total,
        'paid_amount',i.paid_amount,'balance',i.balance,'change_amount',i.change_amount,'status',i.status)
        from invoices i where i.id = v_existing_invoice_id);
    end if;
  end if;

  if p_items is null or jsonb_array_length(p_items)=0 then raise exception 'ERR_EMPTY_CART'; end if;

  if p_session_id is not null then
    select id into v_session from cashier_sessions where id=p_session_id and tenant_id=v_t and status='OPEN';
  else
    select id into v_session from cashier_sessions
      where tenant_id=v_t and branch_id=p_branch_id and cashier_id=v_uid and status='OPEN'
      order by opened_at desc limit 1;
  end if;
  if v_session is null then raise exception 'ERR_NO_OPEN_SESSION'; end if;

  -- ===== D6: server-authoritative tax (sign-off #2) =====================
  -- Resolved ONCE per sale (every seeded tax_rules row is applies_to='ALL' — no per-line variation
  -- exists), BEFORE next_number for the same reason as the idempotency guard: fail fast, don't burn a
  -- document number on a tax-config error. No-active-rule = RAISE, not silent-0 (bug class #7).
  select rate, mode into v_tax_rate, v_tax_mode from tax_rules
    where tenant_id=v_t and is_default=true and is_active=true
      and (effective_from is null or effective_from <= current_date)
      and (effective_until is null or effective_until >= current_date)
    limit 1;
  if v_tax_rate is null then raise exception 'ERR_NO_ACTIVE_TAX_RULE'; end if;
  -- The line math below (v_taxable * v_tp/100, added on top) is EXCLUSIVE-mode arithmetic only.
  -- Every is_default row today is EXCLUSIVE (GST 17%); raise rather than silently mis-total an
  -- INCLUSIVE default if one is ever configured — a new silent-wrong-total bug is not the fix.
  if v_tax_mode <> 'EXCLUSIVE' then raise exception 'ERR_TAX_MODE_UNSUPPORTED: %', v_tax_mode; end if;

  v_number := public.next_number('INVOICE'::number_series_type_enum, p_branch_id);

  insert into invoices (id, tenant_id, branch_id, invoice_number, customer_id, cashier_id, session_id,
                        status, sale_type, notes, created_by, updated_by, idempotency_key)
  values (v_invoice, v_t, p_branch_id, v_number, p_customer_id, v_uid, v_session, 'DRAFT', 'CASH', p_notes, v_uid, v_uid, p_idempotency_key);

  for r in select * from jsonb_array_elements(p_items) loop
    v_pid := (r->>'product_id')::uuid;
    v_qty := coalesce((r->>'qty')::numeric, 1);
    v_unit := coalesce((r->>'unit_price')::numeric, 0);
    v_dp := coalesce((r->>'discount_pct')::numeric, 0);
    v_tp := v_tax_rate;
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
  -- Dr paid(resolved per method) + Dr AR(balance) = Cr Revenue(subtotal-disc) + Cr OutputTax(tax); plus Dr COGS / Cr Inventory.
  -- S2a: each payment resolves to its GL account via resolve_payment_account, grouped (split tender → one debit/account).
  declare
    v_cogs numeric; v_rev numeric := v_subtotal - v_disc; v_lines jsonb := '[]'::jsonb; v_pay record;
  begin
    select coalesce(sum(cost_price*qty),0) into v_cogs from invoice_items where invoice_id=v_invoice;
    -- Σ payment debits = v_paid (full tender). Change is returned in cash → credit it back to Cash so Σ debits net to v_applied.
    for v_pay in
      select public.resolve_payment_account(v_t, p.method::text, p.bank_account_id) as acct, sum(p.amount) as amt
      from payments p where p.invoice_id = v_invoice group by 1
    loop
      v_lines := v_lines || jsonb_build_object('account_code', v_pay.acct, 'debit', v_pay.amt);
    end loop;
    if v_change > 0 then v_lines := v_lines
        || jsonb_build_object('account_code', public.resolve_payment_account(v_t,'CASH',null), 'credit', v_change); end if;
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

  -- ===== WhatsApp receipt enqueue (best-effort; MUST NEVER fail a sale) =====
  -- Own sub-block, swallows ALL exceptions (incl. unique_violation — otherwise it would bubble to the
  -- outer handler and be misread as an idempotency race). Only when the sale has a customer WITH a
  -- phone; walk-in / no-phone yields no SELECT row → nothing enqueued. The PDF is attached later by
  -- the receipt-sender edge fn. Fires once per invoice (replay guard already returned above).
  begin
    insert into communication_logs (tenant_id, customer_id, invoice_id, channel,
      template_code, status, recipient, payload)
    select v_t, c.id, v_invoice, 'WHATSAPP', 'SALE_RECEIPT', 'PENDING',
           nullif(c.phone,''),
           jsonb_build_object('invoice_number', v_number, 'grand_total', v_grand)
    from customers c
    where c.id = p_customer_id and nullif(c.phone,'') is not null
    on conflict (invoice_id) where template_code = 'SALE_RECEIPT' and invoice_id is not null
      do nothing;
  exception when others then null;
  end;

  return jsonb_build_object('invoice_id',v_invoice,'invoice_number',v_number,'grand_total',v_grand,
    'paid_amount',v_applied,'balance',v_balance,'change_amount',v_change,'status',v_status);

exception
  when unique_violation then
    -- Concurrent replay of the same key won the race (uq_invoices_idem). This subtransaction rolls back —
    -- correct: the loser's work SHOULD be discarded. Re-read and return the winner. Only genuine idempotency
    -- races are swallowed; any OTHER unique_violation re-raises so existing error behavior is unchanged.
    if p_idempotency_key is not null then
      select i.id into v_existing_invoice_id from invoices i
       where i.tenant_id = v_t and i.idempotency_key = p_idempotency_key;
      if found then
        return (select jsonb_build_object('invoice_id',i.id,'invoice_number',i.invoice_number,'grand_total',i.grand_total,
          'paid_amount',i.paid_amount,'balance',i.balance,'change_amount',i.change_amount,'status',i.status)
          from invoices i where i.id = v_existing_invoice_id);
      end if;
    end if;
    raise;
end;
$$;
