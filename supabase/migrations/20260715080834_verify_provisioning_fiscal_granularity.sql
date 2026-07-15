-- Harden verify_tenant_provisioning against the period-granularity class of drift.
-- It previously only checked open_fiscal_period > 0, which an ANNUAL period satisfies — so it could NOT
-- have caught the P2 annual-seed defect. Add fiscal_period_monthly: the covering OPEN period must be a
-- calendar month (end_date = month-end of start_date). Fold it into `complete` and surface it as a field,
-- so the verify_provisioning_daily monitor catches granularity drift, not just absence.
-- Read-only (STABLE); everything else byte-for-byte from the live definition.

create or replace function public.verify_tenant_provisioning(p_tenant_id uuid)
returns jsonb
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  v_missing_accounts text[]; v_missing_series text[]; v_tax int; v_period int;
  v_sms int; v_email int; v_sentinel int; v_wh int; v_complete boolean; v_month_ok boolean;
  -- EXPECTED CoA — 20 codes, flat, is_system (P0.2 golden: Demo Store). Verify names/types against the dump.
  v_expected_accounts text[] := array['1000','1010','1100','1150','1200','1300','2000','2100','2120','3000',
                                      '3100','4000','4100','4200','5000','5100','5200','6000','6100','6200'];
  -- EXPECTED series = the GOLDEN 8 THAT ACTUALLY WORK (P0.3), NOT the 10 enum labels.
  -- JOURNAL_ENTRY + RECEIPT_VOUCHER are in the enum but seeded by NO tenant → including them would report
  -- every tenant incomplete (false alarm). STOCK_COUNT is live and required (Ahmad Store is missing it).
  v_expected_series text[] := array['INVOICE','PURCHASE_ORDER','GRN','STOCK_TRANSFER','STOCK_COUNT',
                                    'REPAIR_JOB','PAYMENT_VOUCHER','PURCHASE_RETURN'];
begin
  select coalesce(array_agg(x), '{}') into v_missing_accounts from unnest(v_expected_accounts) x
    where not exists (select 1 from accounts a where a.tenant_id=p_tenant_id and a.code=x and a.deleted_at is null);
  select coalesce(array_agg(x), '{}') into v_missing_series from unnest(v_expected_series) x
    where not exists (select 1 from number_series ns where ns.tenant_id=p_tenant_id and ns.type::text=x);
  select count(*) into v_tax from tax_rules where tenant_id=p_tenant_id and deleted_at is null;
  select count(*) into v_period from fiscal_periods where tenant_id=p_tenant_id and status='OPEN'
    and current_date between start_date and end_date;
  -- granularity: the covering OPEN period must be a calendar month (end_date = month-end of start_date).
  -- An annual period satisfies open_fiscal_period>0 but fails this — that was the P2 divergence blind spot.
  select exists (
    select 1 from fiscal_periods where tenant_id=p_tenant_id and status='OPEN'
      and current_date between start_date and end_date
      and end_date = (date_trunc('month', start_date) + interval '1 month - 1 day')::date
  ) into v_month_ok;
  select count(*) into v_sms from sms_templates where tenant_id=p_tenant_id;
  select count(*) into v_email from email_templates where tenant_id=p_tenant_id;
  select count(*) into v_sentinel from products where tenant_id=p_tenant_id and sku='REPAIR-SERVICE' and deleted_at is null;
  -- default warehouse per branch (golden has 1 "Main Warehouse" is_default). Branches with none:
  select count(*) into v_wh from branches b where b.tenant_id=p_tenant_id
    and not exists (select 1 from warehouses w where w.branch_id=b.id and w.is_default);

  v_complete := (array_length(v_missing_accounts,1) is null) and (array_length(v_missing_series,1) is null)
                and v_tax > 0 and v_period > 0 and v_month_ok and v_sms > 0 and v_email > 0 and v_sentinel = 1 and v_wh = 0;

  return jsonb_build_object(
    'tenant_id', p_tenant_id, 'complete', v_complete,
    'missing_accounts', v_missing_accounts, 'missing_number_series', v_missing_series,
    'tax_rules', v_tax, 'open_fiscal_period', v_period,          -- 0 = CANNOT POST ANY JOURNAL
    'fiscal_period_monthly', v_month_ok,                         -- false = wrong-granularity (e.g. annual) period
    'sms_templates', v_sms, 'email_templates', v_email, 'repair_service_sentinel', v_sentinel,
    'branches_without_default_warehouse', v_wh);
end; $function$;
