-- FIX: disburse_salary_advance had the same 22P02 bug as disburse_payroll_run —
-- `select post_journal(...) into v_je` assigns jsonb into a uuid. Extract ->>'journal_entry_id'.
-- Forward create-or-replace; only the post_journal INTO assignment changes.
create or replace function public.disburse_salary_advance(p_employee_id uuid, p_amount numeric, p_recovery_amount numeric, p_pay_account character varying, p_notes text)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid(); v_branch uuid; v_id uuid; v_je uuid;
        v_pay text := coalesce(p_pay_account,'1000'); v_lines jsonb;
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
end; $function$;
