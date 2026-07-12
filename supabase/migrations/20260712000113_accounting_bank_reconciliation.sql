-- Start a reconciliation: snapshot statement balance vs current ledger balance of the bank's chart account.
-- ledger_balance = the linked chart_account_id's current_balance (books). status DRAFT.
create or replace function public.create_bank_reconciliation(
  p_bank_account_id uuid, p_statement_date date, p_statement_balance numeric,
  p_unreconciled_items jsonb default null, p_notes text default null
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_chart uuid; v_ledger numeric; v_recon_id uuid;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select chart_account_id into v_chart from bank_accounts where id=p_bank_account_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_BANK_ACCOUNT_NOT_FOUND'; end if;
  -- books balance: prefer the linked chart account's current_balance; fall back to the bank account's own
  select coalesce((select current_balance from accounts where id=v_chart),
                  (select current_balance from bank_accounts where id=p_bank_account_id))
    into v_ledger;
  insert into bank_reconciliations (tenant_id, bank_account_id, statement_date, statement_balance,
    ledger_balance, unreconciled_items_json, status, notes)
  values (v_t, p_bank_account_id, p_statement_date, round(p_statement_balance,4),
    round(coalesce(v_ledger,0),4), p_unreconciled_items, 'DRAFT', p_notes)
  returning id into v_recon_id;
  return jsonb_build_object('reconciliation_id', v_recon_id, 'ledger_balance', coalesce(v_ledger,0),
    'statement_balance', round(p_statement_balance,4), 'difference', round(p_statement_balance - coalesce(v_ledger,0),4));
end; $function$;

-- Complete a reconciliation: set reconciled_balance, status COMPLETED, stamp reconciled_by/at.
create or replace function public.complete_bank_reconciliation(
  p_reconciliation_id uuid, p_reconciled_balance numeric, p_unreconciled_items jsonb default null, p_notes text default null
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid(); v_status reconciliation_status_enum;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','approve') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select status into v_status from bank_reconciliations where id=p_reconciliation_id and tenant_id=v_t;
  if not found then raise exception 'ERR_RECONCILIATION_NOT_FOUND'; end if;
  if v_status = 'COMPLETED' then raise exception 'ERR_ALREADY_COMPLETED'; end if;
  update bank_reconciliations
    set reconciled_balance=round(p_reconciled_balance,4), status='COMPLETED',
        reconciled_by=v_uid, reconciled_at=now(),
        unreconciled_items_json=coalesce(p_unreconciled_items, unreconciled_items_json),
        notes=coalesce(p_notes, notes), updated_at=now(), version=version+1
    where id=p_reconciliation_id;
  return jsonb_build_object('reconciliation_id', p_reconciliation_id, 'status', 'COMPLETED');
end; $function$;