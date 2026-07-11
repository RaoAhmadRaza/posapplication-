-- M07 A5 hook: record_supplier_payment auto-posts a balanced SUPPLIER_PAYMENT journal.
-- Dr 2000 AP / Cr 1000 Cash (or 1010 Bank when bank_account_id present). Ungated system
-- post (p_gate=false) so a purchase user without accounting:create can still pay a supplier.
-- Body reproduced verbatim from the live def; only the GL block before RETURN is new.
CREATE OR REPLACE FUNCTION public.record_supplier_payment(p_supplier_id uuid, p_invoice_id uuid, p_method payment_method_enum, p_amount numeric, p_reference character varying, p_bank_account_id uuid, p_notes text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_branch uuid; v_num text; v_pay_id uuid; v_bal numeric; v_paid numeric; v_total numeric;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'ERR_BAD_AMOUNT'; end if;
  if not exists (select 1 from suppliers where id=p_supplier_id and tenant_id=v_t) then raise exception 'ERR_SUPPLIER_NOT_FOUND'; end if;

  -- branch for voucher numbering: from the invoice's PO if present, else caller's first assigned branch
  if p_invoice_id is not null then
    select pi.balance, pi.paid_amount, pi.total_amount, po.branch_id
      into v_bal, v_paid, v_total, v_branch
      from purchase_invoices pi join purchase_orders po on po.id=pi.po_id
      where pi.id=p_invoice_id and pi.tenant_id=v_t and pi.deleted_at is null;
    if not found then raise exception 'ERR_INVOICE_NOT_FOUND'; end if;
    if p_amount > v_bal then raise exception 'ERR_OVERPAYMENT'; end if;
  else
    select branch_id into v_branch from user_branch_assignments where user_id=v_uid limit 1;
  end if;

  v_num := public.next_number('PAYMENT_VOUCHER', v_branch);

  insert into supplier_payments (tenant_id, supplier_id, invoice_id, method, amount, reference,
    bank_account_id, voucher_number, notes, created_by)
  values (v_t, p_supplier_id, p_invoice_id, p_method, round(p_amount,4), nullif(p_reference,''),
    p_bank_account_id, v_num, p_notes, v_uid)
  returning id into v_pay_id;

  if p_invoice_id is not null then
    update purchase_invoices
      set paid_amount = paid_amount + round(p_amount,4),
          balance     = balance - round(p_amount,4),
          status      = case when balance - round(p_amount,4) <= 0 then 'PAID' else status end,
          updated_at  = now(), version = version + 1
      where id = p_invoice_id;
  end if;

  -- ===== M07 A5: auto-post supplier payment to GL (ungated; mirrors AP balance reduction) =====
  perform public.post_journal(
    v_branch, 'SUPPLIER_PAYMENT', v_pay_id, 'Supplier payment '||v_num,
    jsonb_build_array(
      jsonb_build_object('account_code','2000','debit', round(p_amount,4)),
      jsonb_build_object('account_code', case when p_bank_account_id is not null then '1010' else '1000' end, 'credit', round(p_amount,4))),
    current_date, v_pay_id, false);

  return jsonb_build_object('payment_id', v_pay_id, 'voucher_number', v_num);
end; $function$;
