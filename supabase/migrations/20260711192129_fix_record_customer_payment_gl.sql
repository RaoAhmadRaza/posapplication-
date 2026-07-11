-- Reconcile record_customer_payment. Two prior migrations defined it:
--   20260711184605 (GL-aware: posts Dr cash/bank, Cr AR; sets PARTIALLY_PAID; stores bank_account_id)
--   20260711185637 (later, "no GL hook yet": dropped the GL post, dropped bank_account_id, never sets
--                    PARTIALLY_PAID, generated an unstored RECEIPT_VOUCHER number, updated dead ledger_accounts)
-- 185637 sorts after 184605 so it wins on every replay, silently regressing the GL hook. This forward
-- migration (sorts after both) restores the correct definition:
--   * GL auto-post Dr cash(1000)/bank(1010), Cr AR(1100) — mirrors the invoice balance reduction, ungated.
--   * status -> PAID when cleared, else PARTIALLY_PAID.
--   * persist bank_account_id on the payment row.
-- Dropped from 185637: the RECEIPT_VOUCHER number (payments has no column to store it — it only burned the
-- sequence) and the ledger_accounts update (no CUSTOMER rows exist; AR is carried on invoices.balance, which
-- is what customer_ledger/receivables_aging and the GL both reconcile against).
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
