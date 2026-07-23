-- Make bank reconciliation actually correct the books (P0-MONEY).
-- Before this, complete_bank_reconciliation only stamped status/reconciled_balance
-- and never posted a journal, so a statement-vs-book difference was recorded but
-- never fixed — the control was cosmetic. Now, on completion with a non-zero
-- difference, it posts a balanced adjustment journal that moves the bank's chart
-- account to the reconciled (statement) balance, against an account the CALLER
-- names (bank charges / interest / suspense — the real cause), so nothing is
-- plugged to a guessed literal.
--
-- Not routed through resolve_payment_account: this is not a payment. The bank
-- side is the reconciliation's own bank chart account (deterministic); the
-- contra is caller-supplied. post_journal is called p_gate=false because this
-- RPC already enforces accounting:approve; the journal_entries period-open
-- trigger still blocks posting into a closed period.

alter table public.bank_reconciliations
  add column if not exists adjustment_journal_id uuid references public.journal_entries(id);

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
