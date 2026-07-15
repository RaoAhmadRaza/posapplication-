-- Settings S1: fold payment_methods into provisioning.
-- Separate migration — the applied 20260715080624 provision_tenant is NOT edited.
-- provision_tenant gets ONE new block (8. PAYMENT METHODS); everything else is byte-for-byte the live body.
-- verify_tenant_provisioning gains a payment_methods count (expect 7) folded into `complete`.

-- ================= provision_tenant: + block 8 (payment methods) =================
CREATE OR REPLACE FUNCTION public.provision_tenant(p_tenant_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_start date := date_trunc('year', current_date)::date; v_end date := (date_trunc('year', current_date) + interval '1 year - 1 day')::date;
begin
  if p_tenant_id is null then raise exception 'ERR_TENANT_REQUIRED'; end if;
  if not exists (select 1 from tenants where id=p_tenant_id) then raise exception 'ERR_TENANT_NOT_FOUND'; end if;

  -- ===== 1. CHART OF ACCOUNTS (20) — the flat live set. text->enum needs the explicit cast (VALUES-derived). =====
  insert into accounts (tenant_id, code, name, type, is_system)
  select p_tenant_id, v.code, v.name, v.type::account_type_enum, true
  from (values
    ('1000','Cash','ASSET'), ('1010','Bank','ASSET'), ('1100','Accounts Receivable','ASSET'),
    ('1150','Employee Advances','ASSET'), ('1200','Inventory','ASSET'), ('1300','Input Tax','ASSET'),
    ('2000','Accounts Payable','LIABILITY'), ('2100','Output Tax','LIABILITY'),
    ('2120','Payroll Deductions Payable','LIABILITY'),
    ('3000','Equity','EQUITY'), ('3100','Retained Earnings','EQUITY'),
    ('4000','Sales Revenue','REVENUE'), ('4100','Sales Returns','REVENUE'), ('4200','Service Revenue','REVENUE'),
    ('5000','COGS','EXPENSE'), ('5100','Purchase Returns','EXPENSE'), ('5200','Warranty Cost','EXPENSE'),
    ('6000','Operating Expenses','EXPENSE'), ('6100','Rounding','EXPENSE'), ('6200','Salary Expense','EXPENSE')
  ) as v(code,name,type)
  where not exists (select 1 from accounts a where a.tenant_id=p_tenant_id and a.code=v.code and a.deleted_at is null);

  -- ===== 2. NUMBER SERIES — the GOLDEN 8 (P0.3), tenant-level (branch_id NULL), padding 6. =====
  -- NOT the 10 enum labels: JOURNAL_ENTRY + RECEIPT_VOUCHER are unused by every tenant (see Deferred).
  -- STOCK_COUNT is the one Ahmad Store is missing — this insert is what closes that live drift.
  insert into number_series (tenant_id, branch_id, type, prefix, current_number)
  select p_tenant_id, null, v.type::number_series_type_enum, v.prefix, 0
  from (values
    ('INVOICE','INV-'), ('PURCHASE_ORDER','PO-'), ('GRN','GRN-'), ('STOCK_TRANSFER','TRF-'),
    ('STOCK_COUNT','SC-'), ('REPAIR_JOB','RJ-'), ('PAYMENT_VOUCHER','PV-'), ('PURCHASE_RETURN','PR-')
  ) as v(type,prefix)   -- prefixes + padding MUST match the P0.3 golden dump verbatim
  where not exists (select 1 from number_series ns where ns.tenant_id=p_tenant_id and ns.type::text=v.type and ns.branch_id is null);

  -- ===== 3. TAX RULES (§10 seed) — mode is tax_calculation_mode_enum: cast it. =====
  insert into tax_rules (tenant_id, name, code, rate, mode, is_default, applies_to)
  select p_tenant_id, v.name, v.code, v.rate::numeric, v.mode::tax_calculation_mode_enum, v.is_default::boolean, v.applies_to
  from (values
    ('GST 17%','GST17','17.00','EXCLUSIVE','true','ALL'),
    ('GST 5%','GST5','5.00','EXCLUSIVE','false','ALL'),
    ('GST Exempt','EXEMPT','0.00','EXCLUSIVE','false','ALL'),
    ('GST Inclusive','GST17I','17.00','INCLUSIVE','false','ALL')
  ) as v(name,code,rate,mode,is_default,applies_to)
  where not exists (select 1 from tax_rules tr where tr.tenant_id=p_tenant_id and tr.code=v.code and tr.deleted_at is null);

  -- ===== 4. FISCAL PERIOD — reuse the SOLE creator (current_fiscal_period) so the period model can never
  -- diverge again. It creates the covering MONTHLY period if absent; annual seeding was the P2 defect.
  perform public.current_fiscal_period(p_tenant_id, current_date);

  -- ===== 5. REPAIR-SERVICE sentinel (labour line target; type='SERVICE' = the non-stock signal) =====
  insert into products (tenant_id, sku, name, type, is_active)
  select p_tenant_id, 'REPAIR-SERVICE', 'Repair Service', 'SERVICE'::product_type_enum, true
  where not exists (select 1 from products p where p.tenant_id=p_tenant_id and p.sku='REPAIR-SERVICE');

  -- ===== 6. NOTIFICATION TEMPLATES =====
  insert into sms_templates (tenant_id, name, template_code, body)
  select p_tenant_id, v.name, v.code, v.body
  from (values
    ('Repair status','repair_status_update','Hi {{customer_name}}, your repair {{job_number}} is now {{status}}. - {{shop_name}}'),
    ('Payment reminder','payment_reminder','Reminder: PKR {{amount}} is due on invoice {{invoice_number}}. - {{shop_name}}'),
    ('Repair ready','repair_ready','Good news {{customer_name}}! Repair {{job_number}} is ready for pickup. - {{shop_name}}')
  ) as v(name,code,body)
  where not exists (select 1 from sms_templates s where s.tenant_id=p_tenant_id and s.template_code=v.code and s.language='en');

  insert into email_templates (tenant_id, name, template_code, subject, body_html, body_text)
  select p_tenant_id, v.name, v.code, v.subject, v.html, v.txt
  from (values
    ('Scheduled report','scheduled_report','Your {{report_name}} report','<p>{{report_name}} for {{period}}.</p>','{{report_name}} for {{period}}.'),
    ('Payment reminder','payment_reminder','Payment due: {{invoice_number}}','<p>PKR {{amount}} is due on {{invoice_number}}.</p>','PKR {{amount}} due on {{invoice_number}}.'),
    ('Repair status','repair_status_update','Repair {{job_number}} — {{status}}','<p>Hi {{customer_name}}, repair {{job_number}} is now {{status}}.</p>','Repair {{job_number}} is now {{status}}.')
  ) as v(name,code,subject,html,txt)
  where not exists (select 1 from email_templates e where e.tenant_id=p_tenant_id and e.template_code=v.code and e.language='en');

  -- ===== 7. DEFAULT WAREHOUSE per branch — direct idempotent insert. =====
  -- CANNOT reuse ensure_default_warehouse here: it guards on auth_has_branch(auth.uid()) and there is
  -- NO user context inside this definer seeder (threw 42501 'branch not assigned'). Golden row = 1
  -- 'Main Warehouse'/WH01 is_default per branch; definer bypasses RLS, not-exists makes it idempotent.
  insert into warehouses (tenant_id, branch_id, name, code, is_default, is_active)
  select p_tenant_id, b.id, 'Main Warehouse', 'WH01', true, true
  from branches b
  where b.tenant_id=p_tenant_id
    and not exists (select 1 from warehouses w where w.branch_id=b.id and w.deleted_at is null);

  -- ===== 8. PAYMENT METHODS (§3.14) — 7 per tenant, unmapped (bank_account_id NULL → resolver returns '1000').
  -- Same 7 rows migration 20260715084008 seeds for existing tenants; CASH is_system. Idempotent by (tenant,code).
  insert into payment_methods (tenant_id, name, code, is_system, requires_reference, sort_order)
  select p_tenant_id, v.name, v.code, v.sys::boolean, v.ref::boolean, v.ord::int
  from (values
    ('Cash','CASH','true','false','1'),
    ('Bank Transfer','BANK_TRANSFER','false','true','2'),
    ('Card','CARD','false','false','3'),
    ('Mobile Wallet','MOBILE_WALLET','false','true','4'),
    ('Cheque','CHEQUE','false','true','5'),
    ('Loyalty Points','LOYALTY_POINTS','false','false','6'),
    ('Credit Note','CREDIT_NOTE','false','true','7')
  ) as v(name,code,sys,ref,ord)
  where not exists (select 1 from payment_methods pm where pm.tenant_id=p_tenant_id and pm.code=v.code and pm.deleted_at is null);

  -- inventory_settings: DELIBERATELY NOT SEEDED (0 rows for every tenant incl. golden; lazily defaulted).

  return public.verify_tenant_provisioning(p_tenant_id);
end; $function$;

-- ================= verify_tenant_provisioning: + payment_methods (expect 7) =================
CREATE OR REPLACE FUNCTION public.verify_tenant_provisioning(p_tenant_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_missing_accounts text[]; v_missing_series text[]; v_tax int; v_period int;
  v_sms int; v_email int; v_sentinel int; v_wh int; v_pm int; v_complete boolean; v_month_ok boolean;
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
  -- payment methods: 7 per tenant (one per payment_method_enum label). <7 = a money path can't resolve its GL account.
  select count(*) into v_pm from payment_methods where tenant_id=p_tenant_id and deleted_at is null;

  v_complete := (array_length(v_missing_accounts,1) is null) and (array_length(v_missing_series,1) is null)
                and v_tax > 0 and v_period > 0 and v_month_ok and v_sms > 0 and v_email > 0 and v_sentinel = 1
                and v_wh = 0 and v_pm >= 7;

  return jsonb_build_object(
    'tenant_id', p_tenant_id, 'complete', v_complete,
    'missing_accounts', v_missing_accounts, 'missing_number_series', v_missing_series,
    'tax_rules', v_tax, 'open_fiscal_period', v_period,          -- 0 = CANNOT POST ANY JOURNAL
    'fiscal_period_monthly', v_month_ok,                         -- false = wrong-granularity (e.g. annual) period
    'sms_templates', v_sms, 'email_templates', v_email, 'repair_service_sentinel', v_sentinel,
    'branches_without_default_warehouse', v_wh, 'payment_methods', v_pm);
end; $function$;
