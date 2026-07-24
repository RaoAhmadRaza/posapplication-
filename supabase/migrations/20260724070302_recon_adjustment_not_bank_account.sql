-- Bank reconciliation could silently no-op (P0-MONEY, fails-as-passes).
-- complete_bank_reconciliation posts Dr/Cr between the bank's chart account and a
-- caller-named contra ("adjustment account"). The UI picker offered EVERY account,
-- so a user could pick the bank's own chart account as the contra — then both legs
-- of the adjustment hit the same account, cancel out, and the ledger never moves,
-- yet the RPC still reports COMPLETED. The books stay wrong while the control claims
-- success.
--
-- Fix: reject an adjustment account equal to the bank's own chart account at the
-- trust boundary. A no-op contra is never a valid reconciliation adjustment — the
-- difference must be booked to a REAL cause (bank charges, interest, suspense).
-- Only the guard changes; the rest of the function is identical to 20260723130000.

create or replace function public.complete_bank_reconciliation(
  p_reconciliation_id uuid, p_reconciled_balance numeric,
  p_adjustment_account_code varchar default null,
  p_unreconciled_items jsonb default null, p_notes text default null
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_status reconciliation_status_enum; v_bank uuid; v_chart uuid; v_code varchar;
  v_branch uuid; v_books numeric; v_delta numeric; v_lines jsonb; v_je jsonb; v_je_id uuid;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','approve') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;

  select br.status, br.bank_account_id into v_status, v_bank
    from bank_reconciliations br where br.id=p_reconciliation_id and br.tenant_id=v_t;
  if not found then raise exception 'ERR_RECONCILIATION_NOT_FOUND'; end if;
  if v_status = 'COMPLETED' then raise exception 'ERR_ALREADY_COMPLETED'; end if;

  select ba.chart_account_id, ba.branch_id into v_chart, v_branch
    from bank_accounts ba where ba.id=v_bank and ba.tenant_id=v_t;

  -- Live books balance of the bank's chart account, and the delta needed to
  -- bring it to the reconciled balance. Recomputed live (not the create-time
  -- snapshot) so the ledger lands exactly on the statement figure.
  select current_balance, code into v_books, v_code from accounts where id=v_chart and tenant_id=v_t;
  v_delta := round(p_reconciled_balance,4) - round(coalesce(v_books,0),4);

  if v_delta <> 0 then
    if v_chart is null or v_code is null then raise exception 'ERR_BANK_HAS_NO_CHART_ACCOUNT'; end if;
    if p_adjustment_account_code is null then raise exception 'ERR_ADJUSTMENT_ACCOUNT_REQUIRED'; end if;
    -- Contra cannot be the bank's own chart account: both legs would cancel (no-op).
    if p_adjustment_account_code = v_code then raise exception 'ERR_ADJUSTMENT_SAME_AS_BANK'; end if;

    -- v_delta > 0: books are short of the statement → increase bank (Dr bank / Cr contra).
    -- v_delta < 0: books exceed the statement → decrease bank (Cr bank / Dr contra).
    if v_delta > 0 then
      v_lines := jsonb_build_array(
        jsonb_build_object('account_code', v_code, 'debit', v_delta, 'credit', 0, 'narration', 'Bank reconciliation adjustment'),
        jsonb_build_object('account_code', p_adjustment_account_code, 'debit', 0, 'credit', v_delta, 'narration', 'Bank reconciliation adjustment'));
    else
      v_lines := jsonb_build_array(
        jsonb_build_object('account_code', v_code, 'debit', 0, 'credit', -v_delta, 'narration', 'Bank reconciliation adjustment'),
        jsonb_build_object('account_code', p_adjustment_account_code, 'debit', -v_delta, 'credit', 0, 'narration', 'Bank reconciliation adjustment'));
    end if;

    v_je := public.post_journal(
      p_branch_id => v_branch,
      p_reference_type => 'RECON_ADJUSTMENT',
      p_reference_id => p_reconciliation_id,
      p_description => coalesce(p_notes, 'Bank reconciliation adjustment'),
      p_lines => v_lines,
      p_date => current_date,
      p_gate => false);
    v_je_id := (v_je->>'journal_entry_id')::uuid;
  end if;

  update bank_reconciliations
    set reconciled_balance=round(p_reconciled_balance,4), status='COMPLETED',
        reconciled_by=v_uid, reconciled_at=now(), adjustment_journal_id=v_je_id,
        unreconciled_items_json=coalesce(p_unreconciled_items, unreconciled_items_json),
        notes=coalesce(p_notes, notes), updated_at=now(), version=version+1
    where id=p_reconciliation_id;

  return jsonb_build_object('reconciliation_id', p_reconciliation_id, 'status', 'COMPLETED',
    'adjustment', v_delta, 'adjustment_journal_id', v_je_id);
end; $function$;
