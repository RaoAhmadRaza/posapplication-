-- Mirror of record_supplier_payment for the CUSTOMER (AR) side. Collects against a credit invoice.
-- Receipt voucher number via next_number('RECEIPT_VOUCHER', branch). Branch derived from the invoice.
-- p_method is payment_method_enum. p_bank_account_id nullable (bank_accounts arrives in A3; pass null pre-A3).
create or replace function public.record_customer_payment(
  p_customer_id uuid, p_invoice_id uuid, p_method payment_method_enum, p_amount numeric,
  p_reference varchar, p_bank_account_id uuid, p_notes text
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_branch uuid; v_num text; v_pay_id uuid; v_bal numeric; v_sess uuid;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('sales','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'ERR_BAD_AMOUNT'; end if;
  if not exists (select 1 from customers where id=p_customer_id and tenant_id=v_t) then raise exception 'ERR_CUSTOMER_NOT_FOUND'; end if;

  -- <<< reconcile: read the invoice's branch for voucher numbering; confirm invoices.branch_id exists >>>
  select balance, branch_id into v_bal, v_branch
    from invoices where id=p_invoice_id and tenant_id=v_t and customer_id=p_customer_id;
  if not found then raise exception 'ERR_INVOICE_NOT_FOUND'; end if;
  if p_amount > v_bal then raise exception 'ERR_OVERPAYMENT'; end if;

  v_num := public.next_number('RECEIPT_VOUCHER', v_branch);

  -- payment row: reconcile these columns against how create_sale writes into payments
  -- (session_id, invoice_id, method, amount, reference, notes, created_by). Adjust to the live payments shape.
  insert into payments (tenant_id, invoice_id, method, amount, reference, notes, created_by)
  values (v_t, p_invoice_id, p_method, round(p_amount,4), nullif(p_reference,''), p_notes, v_uid)
  returning id into v_pay_id;

  update invoices
    set paid_amount = paid_amount + round(p_amount,4),
        balance     = balance - round(p_amount,4),
        status      = case when balance - round(p_amount,4) <= 0 then 'PAID' else status end,
        updated_at  = now()
    where id = p_invoice_id;

  -- customer running balance (ledger_accounts arrives in A1; guard so this RPC works pre/post A1)
  update ledger_accounts
    set balance = balance - round(p_amount,4), last_transaction_at = now(), updated_at = now()
    where tenant_id=v_t and entity_type='CUSTOMER' and entity_id=p_customer_id;

  return jsonb_build_object('payment_id', v_pay_id, 'voucher_number', v_num,
    'invoice_balance', v_bal - round(p_amount,4));
end; $function$;