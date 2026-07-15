-- Settings S2c: create_expense + disburse_payroll_run + disburse_salary_advance resolve their money leg via
-- resolve_payment_account. create_expense: was 'case p_payment_method=CASH then 1000 else 1010'. Payroll/advance:
-- coalesce(p_pay_account,'1000') → coalesce(p_pay_account, resolve_payment_account(v_t,'CASH',null)) — explicit
-- p_pay_account still overrides; unmapped default stays 1000. create_voucher unchanged (caller supplies p_lines).

CREATE OR REPLACE FUNCTION public.create_expense(p_branch_id uuid, p_category_id uuid, p_amount numeric, p_tax_amount numeric, p_expense_date date, p_payment_method payment_method_enum, p_bank_account_id uuid, p_reference character varying, p_description text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_acct_code varchar; v_exp_acct uuid; v_num text; v_je jsonb; v_je_id uuid; v_eid uuid; v_credit_code varchar; v_total numeric;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'ERR_BAD_AMOUNT'; end if;
  select a.code into v_acct_code from expense_categories ec join accounts a on a.id=ec.account_id
    where ec.id=p_category_id and ec.tenant_id=v_t;
  if not found then raise exception 'ERR_CATEGORY_NOT_FOUND'; end if;

  v_total := round(coalesce(p_amount,0) + coalesce(p_tax_amount,0), 4);
  v_credit_code := public.resolve_payment_account(v_t, p_payment_method::text, p_bank_account_id);  -- S2c: sole resolver (was CASH?1000:1010)
  v_num := public.next_number('PAYMENT_VOUCHER', p_branch_id);

  -- Dr expense (+ Dr input tax) / Cr cash|bank
  v_je := public.post_journal(p_branch_id, 'EXPENSE', null, coalesce(p_description,'Expense'),
    (case when coalesce(p_tax_amount,0) > 0 then
      jsonb_build_array(
        jsonb_build_object('account_code', v_acct_code, 'debit', round(p_amount,4), 'narration', p_description),
        jsonb_build_object('account_code', '1300', 'debit', round(p_tax_amount,4), 'narration','Input tax'),
        jsonb_build_object('account_code', v_credit_code, 'credit', v_total))
     else
      jsonb_build_array(
        jsonb_build_object('account_code', v_acct_code, 'debit', round(p_amount,4), 'narration', p_description),
        jsonb_build_object('account_code', v_credit_code, 'credit', v_total))
     end),
    coalesce(p_expense_date, current_date), null, false);
  v_je_id := (v_je->>'journal_entry_id')::uuid;

  insert into expenses (tenant_id, branch_id, category_id, expense_number, amount, tax_amount, expense_date,
    payment_method, bank_account_id, reference, description, journal_entry_id, created_by)
  values (v_t, p_branch_id, p_category_id, v_num, round(p_amount,4), round(coalesce(p_tax_amount,0),4),
    coalesce(p_expense_date,current_date), p_payment_method, p_bank_account_id, p_reference, p_description, v_je_id, v_uid)
  returning id into v_eid;

  -- maintain bank balance if paid from bank
  if p_bank_account_id is not null then
    update bank_accounts set current_balance = current_balance - v_total, updated_at=now() where id=p_bank_account_id;
  end if;

  return jsonb_build_object('expense_id', v_eid, 'expense_number', v_num, 'journal_entry_id', v_je_id, 'total', v_total);
end; $function$

;

CREATE OR REPLACE FUNCTION public.disburse_payroll_run(p_run_id uuid, p_pay_account character varying)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid(); v_run payroll_runs%rowtype;
  v_adv_total numeric:=0; v_other numeric; v_pay text := coalesce(p_pay_account, public.resolve_payment_account(v_t,'CASH',null));  -- S2c: resolver default (arg still overrides)
  v_lines jsonb:='[]'::jsonb; v_je uuid; v_item record; v_rec numeric;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('hr','approve') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select * into v_run from payroll_runs where id=p_run_id and tenant_id=v_t;
  if not found then raise exception 'ERR_RUN_NOT_FOUND'; end if;
  if v_run.status <> 'APPROVED' then raise exception 'ERR_RUN_NOT_APPROVED'; end if;

  -- recover advances per item (reduce balance by the 'advance' deduction, capped at balance)
  for v_item in select pi.employee_id, (pi.deductions_json->>'advance')::numeric as adv from payroll_items pi where pi.run_id=p_run_id and coalesce((pi.deductions_json->>'advance')::numeric,0) > 0 loop
    v_rec := v_item.adv;
    -- apply against oldest open advances first
    perform 1;
    update salary_advances sa set balance = greatest(0, sa.balance - v_rec),
        fully_recovered_at = case when sa.balance - v_rec <= 0 then now() else sa.fully_recovered_at end,
        updated_at=now(), version=sa.version+1
      where sa.id = (select id from salary_advances where tenant_id=v_t and employee_id=v_item.employee_id and balance>0 order by disbursed_at asc limit 1);
    v_adv_total := v_adv_total + v_rec;
  end loop;

  v_other := round(v_run.total_deductions - v_adv_total, 4);

  if v_run.total_gross > 0 then
    v_lines := jsonb_build_array(jsonb_build_object('account_code','6200','debit', v_run.total_gross, 'credit', 0));
    if v_adv_total > 0 then v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_code','1150','debit',0,'credit', v_adv_total)); end if;
    if v_other > 0 then v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_code','2120','debit',0,'credit', v_other)); end if;
    if v_run.total_net > 0 then v_lines := v_lines || jsonb_build_array(jsonb_build_object('account_code', v_pay,'debit',0,'credit', v_run.total_net)); end if;
    -- MIRROR H0.4 signature exactly; post_journal returns jsonb → take journal_entry_id
    v_je := (public.post_journal(v_run.branch_id, 'PAYROLL', p_run_id, 'Payroll '||v_run.period, v_lines, current_date, v_run.correlation_id, false))->>'journal_entry_id';
  end if;

  update payroll_items set status='PAID', updated_at=now() where run_id=p_run_id;
  update payroll_runs set status='DISBURSED', disbursed_at=now(), journal_entry_id=v_je, updated_at=now(), version=version+1 where id=p_run_id;
  return jsonb_build_object('run_id', p_run_id, 'journal_entry_id', v_je, 'total_net', v_run.total_net, 'status','DISBURSED');
end; $function$

;

CREATE OR REPLACE FUNCTION public.disburse_salary_advance(p_employee_id uuid, p_amount numeric, p_recovery_amount numeric, p_pay_account character varying, p_notes text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid(); v_branch uuid; v_id uuid; v_je uuid;
        v_pay text := coalesce(p_pay_account, public.resolve_payment_account(v_t,'CASH',null)); v_lines jsonb;  -- S2c: resolver default (arg still overrides)
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('hr','approve') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;  -- money → manager/HR
  if p_amount is null or p_amount <= 0 then raise exception 'ERR_BAD_AMOUNT'; end if;
  select branch_id into v_branch from employees where id=p_employee_id and tenant_id=v_t and deleted_at is null;
  if v_branch is null then raise exception 'ERR_EMP_NOT_FOUND'; end if;

  v_lines := jsonb_build_array(
    jsonb_build_object('account_code','1150','debit', round(p_amount,4), 'credit', 0),
    jsonb_build_object('account_code', v_pay,'debit', 0, 'credit', round(p_amount,4)));
  -- post_journal returns jsonb {total,entry_number,journal_entry_id} → take the id
  v_je := (public.post_journal(v_branch, 'SALARY_ADVANCE', gen_random_uuid(), 'Salary advance', v_lines, current_date, null, false))->>'journal_entry_id';

  insert into salary_advances (tenant_id, employee_id, amount, balance, recovery_amount, disbursed_at,
    disbursed_by, journal_entry_id, notes)
  values (v_t, p_employee_id, round(p_amount,4), round(p_amount,4), coalesce(p_recovery_amount, round(p_amount,4)),
    now(), v_uid, v_je, p_notes)
  returning id into v_id;
  return jsonb_build_object('advance_id', v_id, 'journal_entry_id', v_je, 'balance', round(p_amount,4));
end; $function$

;

