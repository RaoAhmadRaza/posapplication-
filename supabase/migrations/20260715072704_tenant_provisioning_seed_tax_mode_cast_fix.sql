-- Fix: provision_tenant() threw 42804 on the tax_rules seed — tax_rules.mode is
-- tax_calculation_mode_enum but the VALUES-derived v.mode went in as bare text with no
-- implicit text->enum cast, so the whole function aborted and seeded NOTHING (same bug
-- class as notify_status_enum_cast_fix). Fix = cast v.mode::tax_calculation_mode_enum.
-- applies_to is varchar (no cast needed). Body otherwise byte-identical to the seed migration.

create or replace function public.provision_tenant(p_tenant_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
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

  -- ===== 4. FISCAL PERIOD — THE ONE THAT BLOCKS ALL JOURNALS. Current-year OPEN period. =====
  insert into fiscal_periods (tenant_id, name, start_date, end_date, status)
  select p_tenant_id, to_char(v_start,'YYYY'), v_start, v_end, 'OPEN'
  where not exists (select 1 from fiscal_periods fp where fp.tenant_id=p_tenant_id
                      and current_date between fp.start_date and fp.end_date);

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

  -- inventory_settings: DELIBERATELY NOT SEEDED (0 rows for every tenant incl. golden; lazily defaulted).

  return public.verify_tenant_provisioning(p_tenant_id);
end; $function$;
