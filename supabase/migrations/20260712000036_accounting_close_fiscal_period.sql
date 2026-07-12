-- Close a fiscal period: OPEN → CLOSED. The existing trg_journal_check_period trigger then rejects
-- any new journal_entries into this period (ERR_ACCOUNTING_PERIOD_CLOSED). Gated accounting:approve.
create or replace function public.close_fiscal_period(p_period_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid(); v_status fiscal_period_status_enum;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','approve') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select status into v_status from fiscal_periods where id=p_period_id and tenant_id=v_t;
  if not found then raise exception 'ERR_PERIOD_NOT_FOUND'; end if;
  if v_status = 'LOCKED' then raise exception 'ERR_PERIOD_LOCKED'; end if;   -- LOCKED is terminal
  if v_status = 'CLOSED' then raise exception 'ERR_PERIOD_ALREADY_CLOSED'; end if;
  update fiscal_periods
    set status='CLOSED', closed_by=v_uid, closed_at=now(), updated_at=now()
    where id=p_period_id;
  return jsonb_build_object('period_id', p_period_id, 'status', 'CLOSED');
end; $function$;

-- Reopen a CLOSED period (not LOCKED). Same gate. Needed because auto-post creates future periods
-- on demand via current_fiscal_period — if someone closes the current month by mistake, sales would
-- start failing to post. Reopen is the escape hatch. LOCKED stays terminal (year-end seal).
create or replace function public.reopen_fiscal_period(p_period_id uuid)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_status fiscal_period_status_enum;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','approve') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select status into v_status from fiscal_periods where id=p_period_id and tenant_id=v_t;
  if not found then raise exception 'ERR_PERIOD_NOT_FOUND'; end if;
  if v_status = 'LOCKED' then raise exception 'ERR_PERIOD_LOCKED'; end if;
  update fiscal_periods set status='OPEN', closed_by=null, closed_at=null, updated_at=now() where id=p_period_id;
  return jsonb_build_object('period_id', p_period_id, 'status', 'OPEN');
end; $function$;