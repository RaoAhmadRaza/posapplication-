-- Reports what a tenant is missing. Read-only. Doubles as the gate for P2–P4 and as an ongoing health check.
-- ⚠️ RECONCILE the expected lists to the P0.2/P0.3/P0.4 dumps before pushing.
create or replace function public.verify_tenant_provisioning(p_tenant_id uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $function$
declare
  v_missing_accounts text[]; v_missing_series text[]; v_tax int; v_period int;
  v_sms int; v_email int; v_sentinel int; v_wh int; v_complete boolean;
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
  select count(*) into v_sms from sms_templates where tenant_id=p_tenant_id;
  select count(*) into v_email from email_templates where tenant_id=p_tenant_id;
  select count(*) into v_sentinel from products where tenant_id=p_tenant_id and sku='REPAIR-SERVICE' and deleted_at is null;
  -- default warehouse per branch (golden has 1 "Main Warehouse" is_default). Branches with none:
  select count(*) into v_wh from branches b where b.tenant_id=p_tenant_id
    and not exists (select 1 from warehouses w where w.branch_id=b.id and w.is_default);

  v_complete := (array_length(v_missing_accounts,1) is null) and (array_length(v_missing_series,1) is null)
                and v_tax > 0 and v_period > 0 and v_sms > 0 and v_email > 0 and v_sentinel = 1 and v_wh = 0;

  return jsonb_build_object(
    'tenant_id', p_tenant_id, 'complete', v_complete,
    'missing_accounts', v_missing_accounts, 'missing_number_series', v_missing_series,
    'tax_rules', v_tax, 'open_fiscal_period', v_period,          -- 0 = CANNOT POST ANY JOURNAL
    'sms_templates', v_sms, 'email_templates', v_email, 'repair_service_sentinel', v_sentinel,
    'branches_without_default_warehouse', v_wh);
end; $function$;

-- convenience: report across all tenants
create or replace function public.verify_all_tenants_provisioning()
returns setof jsonb language sql stable security definer set search_path to 'public' as $$
  select public.verify_tenant_provisioning(id) from public.tenants order by name;
$$;
revoke execute on function public.verify_tenant_provisioning(uuid) from anon;
revoke execute on function public.verify_all_tenants_provisioning() from anon;