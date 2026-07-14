-- disburse_payroll_run: APPROVED→DISBURSED. Posts ONE balanced journal (reference_type PAYROLL) and reduces
-- each recovered salary_advance's balance. Gated hr:approve (manager/HR — pipeline security). Post-on-disburse.
-- GL: Dr 6200 Salary Expense = total_gross
--     Cr 1150 Employee Advances = Σ advance recovered (asset down)
--     Cr 2120 Payroll Deductions Payable = total_deductions − advance recovered (tax/loans held)
--     Cr 1000 Cash = total_net
-- Balanced: gross = net + advance + other_deductions.  p_pay_account default '1000' (bank split deferred, per M07).
create or replace function public.disburse_payroll_run(p_run_id uuid, p_pay_account varchar)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid:=public.auth_tenant_id(); v_uid uuid:=auth.uid(); v_run payroll_runs%rowtype;
  v_adv_total numeric:=0; v_other numeric; v_pay text := coalesce(p_pay_account,'1000');
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
    -- MIRROR H0.4 signature exactly:
    select public.post_journal(v_run.branch_id, 'PAYROLL', p_run_id, 'Payroll '||v_run.period, v_lines, current_date, v_run.correlation_id, false) into v_je;
  end if;

  update payroll_items set status='PAID', updated_at=now() where run_id=p_run_id;
  update payroll_runs set status='DISBURSED', disbursed_at=now(), journal_entry_id=v_je, updated_at=now(), version=version+1 where id=p_run_id;
  return jsonb_build_object('run_id', p_run_id, 'journal_entry_id', v_je, 'total_net', v_run.total_net, 'status','DISBURSED');
end; $function$;