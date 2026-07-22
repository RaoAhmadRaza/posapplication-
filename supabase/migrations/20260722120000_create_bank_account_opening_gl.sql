-- BANK-OPENING bug: the create form captured opening_balance and wrote it to the
-- opening_balance column, but nothing ever seeded current_balance (defaults 0) and
-- nothing posted the opening cash to the GL. The list card shows current_balance, so
-- every new account read Rs 0, and every running balance stayed off by the opening
-- amount forever. Unlike expenses/vouchers, bank creation was plain client CRUD with
-- no post_journal call, so the balance sheet never saw the opening cash either.
--
-- Fix mirrors create_expense/create_voucher: one gated security-definer RPC that
-- inserts the row with current_balance = opening_balance AND, when opening != 0,
-- posts the double-entry via post_journal (the only journal writer) — Dr the bank's
-- linked chart account / Cr Owner Equity (3000), the standard opening-balance-equity
-- entry. Sign is handled so an overdraft (negative) opening balance flips the entry
-- instead of tripping post_journal's one-side-per-line check.
--
-- Branch: the create flow carries no branch (bank_accounts.branch_id is optional and
-- the form has no branch field), so the opening journal posts with a null branch —
-- next_number() and journal_entries.branch_id both allow it. No UI change.
--
-- The direct "bank gated insert" RLS policy is dropped so the GL invariant can't be
-- bypassed by a raw client insert; gated update stays (edits don't touch the GL).

create or replace function public.create_bank_account(
  p_account_name   varchar,
  p_bank_name      varchar,
  p_account_number varchar,
  p_iban           varchar,
  p_swift_code     varchar,
  p_currency       varchar,
  p_opening_balance numeric,
  p_chart_account_id uuid,
  p_is_active      boolean
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id();
  v_id uuid;
  v_open numeric := round(coalesce(p_opening_balance, 0), 4);
  v_code varchar;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;

  insert into bank_accounts (tenant_id, account_name, bank_name, account_number, iban,
    swift_code, currency, opening_balance, current_balance, chart_account_id, is_active)
  values (v_t, p_account_name, p_bank_name, p_account_number, p_iban,
    p_swift_code, coalesce(p_currency,'PKR'), v_open, v_open, p_chart_account_id, coalesce(p_is_active,true))
  returning id into v_id;

  -- opening balance → GL: Dr bank's chart account / Cr Owner Equity (3000)
  if v_open <> 0 then
    if p_chart_account_id is null then raise exception 'ERR_CHART_ACCOUNT_REQUIRED'; end if;
    select code into v_code from accounts where id = p_chart_account_id and tenant_id = v_t;
    if v_code is null then raise exception 'ERR_ACCOUNT_NOT_FOUND'; end if;

    perform public.post_journal(null, 'BANK_OPENING', v_id,
      'Bank opening balance: '||p_account_name,
      case when v_open > 0 then
        jsonb_build_array(
          jsonb_build_object('account_code', v_code, 'debit',  v_open,  'narration','Opening balance'),
          jsonb_build_object('account_code', '3000', 'credit', v_open,  'narration','Opening balance'))
      else
        jsonb_build_array(
          jsonb_build_object('account_code', '3000', 'debit',  -v_open, 'narration','Opening balance'),
          jsonb_build_object('account_code', v_code, 'credit', -v_open, 'narration','Opening balance'))
      end,
      current_date, null, false);   -- p_gate=false: already gated above
  end if;

  return jsonb_build_object('bank_account_id', v_id);
end; $function$;

revoke all on function public.create_bank_account(varchar, varchar, varchar, varchar, varchar, varchar, numeric, uuid, boolean)
  from public, anon;
grant execute on function public.create_bank_account(varchar, varchar, varchar, varchar, varchar, varchar, numeric, uuid, boolean)
  to authenticated;

-- Force all inserts through the RPC so the opening GL entry can't be skipped.
drop policy if exists "bank gated insert" on public.bank_accounts;
