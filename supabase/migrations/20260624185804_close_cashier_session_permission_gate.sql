-- Reconciled against DATABASE_SCHEMA.md (cashier_sessions, payments, invoices) + live function dump.
-- Additive behaviour only: same args, same return Map, same calculations. Adds two guards.
create or replace function public.close_cashier_session(
  p_session_id uuid,
  p_closing_float numeric,
  p_notes text default null
) returns jsonb
  language plpgsql
  security definer
  set search_path to 'public'
as $function$
declare
  v_t uuid := public.auth_tenant_id();
  v_uid uuid := auth.uid();
  v_owner uuid;
  v_open numeric; v_cash numeric; v_sales numeric; v_txns int; v_expected numeric; v_var numeric;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;

  -- GUARD 1: caller must have sales:create (matches open_cashier_session)
  if not public.auth_has_permission('sales','create') then
    raise exception 'ERR_PERMISSION_DENIED' using errcode='42501';
  end if;

  -- fetch owner + opening float, tenant-scoped, must be OPEN
  select cashier_id, opening_float into v_owner, v_open
  from cashier_sessions
  where id = p_session_id and tenant_id = v_t and status = 'OPEN';
  if not found then raise exception 'ERR_SESSION_NOT_OPEN'; end if;

  -- GUARD 2: only the owning cashier may close, unless caller has sales:approve (manager override)
  if v_owner <> v_uid and not public.auth_has_permission('sales','approve') then
    raise exception 'ERR_NOT_SESSION_OWNER' using errcode='42501';
  end if;

  -- unchanged from live function:
  select coalesce(sum(p.amount),0) into v_cash from payments p
    join invoices i on i.id = p.invoice_id
    where i.session_id = p_session_id and p.method = 'CASH';
  select coalesce(sum(i.grand_total),0), count(*) into v_sales, v_txns
    from invoices i where i.session_id = p_session_id;
  v_expected := v_open + v_cash;
  v_var := coalesce(p_closing_float,0) - v_expected;

  update cashier_sessions
    set closing_float = coalesce(p_closing_float,0),
        expected_float = v_expected,
        cash_variance = v_var,
        total_sales = v_sales,
        total_transactions = v_txns,
        status = 'CLOSED',
        closed_at = now(),
        closed_by = v_uid,
        notes = coalesce(p_notes, notes),
        updated_at = now(),
        version = version + 1
    where id = p_session_id;

  return jsonb_build_object(
    'expected_float', v_expected,
    'closing_float', coalesce(p_closing_float,0),
    'cash_variance', v_var,
    'total_sales', v_sales,
    'total_transactions', v_txns
  );
end;
$function$;