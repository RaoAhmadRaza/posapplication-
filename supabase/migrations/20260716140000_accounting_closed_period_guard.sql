-- Same signature → create or replace is a clean replacement (no overload, ACL preserved). The ONLY change vs the
-- D0.5-dumped live body is the CLOSED-PERIOD GUARD inserted right after v_period is resolved.
create or replace function public.post_journal(p_branch_id uuid, p_reference_type character varying, p_reference_id uuid, p_description text, p_lines jsonb, p_date date default current_date, p_correlation_id uuid default null::uuid, p_gate boolean default true)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_period uuid; v_num text; v_je uuid;
  v_line jsonb; v_acct uuid; v_d numeric; v_c numeric; v_sum_d numeric := 0; v_sum_c numeric := 0;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if p_gate and not public.auth_has_permission('accounting','create') then
    raise exception 'ERR_PERMISSION_DENIED' using errcode='42501';
  end if;
  if p_lines is null or jsonb_array_length(p_lines) < 2 then raise exception 'ERR_JOURNAL_MIN_TWO_LINES'; end if;

  v_period := public.current_fiscal_period(v_t, coalesce(p_date, current_date));

  -- === CLOSED-PERIOD GUARD (new — nothing enforced fiscal_periods.status before this) ===
  -- Deliberately UNCONDITIONAL, not behind p_gate: p_gate is a PERMISSION switch (auto-posts pass false to
  -- skip accounting:create). A closed period is an ACCOUNTING control, not a permission — an auto-post must
  -- not be able to write into a closed book just because it isn't user-initiated.
  if (select fp.status from fiscal_periods fp where fp.id = v_period) = 'CLOSED' then
    raise exception 'ERR_PERIOD_CLOSED';
  end if;

  v_num := public.next_number('JOURNAL_ENTRY', p_branch_id);

  insert into journal_entries (tenant_id, entry_number, reference_id, reference_type, description,
    period_id, branch_id, posted_by, correlation_id)
  values (v_t, v_num, p_reference_id, p_reference_type, p_description, v_period, p_branch_id, v_uid, p_correlation_id)
  returning id into v_je;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_acct := public.acct_id(v_t, (v_line->>'account_code'));
    if v_acct is null then raise exception 'ERR_ACCOUNT_NOT_FOUND: %', (v_line->>'account_code'); end if;
    v_d := round(coalesce((v_line->>'debit')::numeric,0),4);
    v_c := round(coalesce((v_line->>'credit')::numeric,0),4);
    if (v_d > 0 and v_c > 0) or (v_d = 0 and v_c = 0) then raise exception 'ERR_JOURNAL_LINE_ONE_SIDE'; end if;
    v_sum_d := v_sum_d + v_d; v_sum_c := v_sum_c + v_c;
    insert into journal_lines (journal_entry_id, account_id, debit, credit, narration, branch_id)
    values (v_je, v_acct, v_d, v_c, v_line->>'narration', p_branch_id);
    -- maintain account running balance (debit +, credit − by natural sign; report layer normalises by type)
    update accounts set current_balance = current_balance + v_d - v_c, updated_at = now() where id = v_acct;
  end loop;

  if round(v_sum_d,4) <> round(v_sum_c,4) then
    raise exception 'ERR_JOURNAL_UNBALANCED: debits % <> credits %', v_sum_d, v_sum_c using errcode='check_violation';
  end if;

  return jsonb_build_object('journal_entry_id', v_je, 'entry_number', v_num, 'total', v_sum_d);
end; $function$;
