-- D1: seed the missing JOURNAL_ENTRY / RECEIPT_VOUCHER number series.
-- Sign-off #3 ("seed or drop") is not a real choice: Postgres has ALTER TYPE ADD VALUE but no
-- DROP VALUE, so dropping the labels means recreating number_series_type_enum, altering every
-- dependent column, and drop+recreating next_number — all to delete two unused strings. Seeding
-- is two INSERTs. SALES_RETURN is NOT added: D0.1 proved it is not a valid enum label at all.

-- BUG CLASS #1 (text->enum, hit 3x, in CLAUDE.md): a bare literal casts fine, but a value flowing
-- through a VALUES list loses the cast -> 42804. Every insert below carries the explicit
-- ::number_series_type_enum.

-- D1.1 Backfill all EXISTING tenants. Idempotent (not exists), safe to re-run.
insert into public.number_series (tenant_id, branch_id, type, prefix, current_number, padding, include_branch_code)
select t.id, null, v.t::number_series_type_enum, v.p, 0, 6, true
from tenants t
cross join (values ('JOURNAL_ENTRY','JV-'), ('RECEIPT_VOUCHER','RV-')
           ) as v(t, p)
where not exists (
  select 1 from number_series ns where ns.tenant_id = t.id and ns.type = v.t::number_series_type_enum
);

-- D1.2 Extend provision_tenant so NEW tenants get them too. Ahmad Store (created 2026-06-18,
-- after the stock_ops backfill loop) is the standing proof a backfill without a provisioner
-- change just recreates the same victim later. Body is byte-identical to the D0.6 dump except
-- the NUMBER SERIES values list (+JOURNAL_ENTRY/+RECEIPT_VOUCHER) and its comment, corrected —
-- the old comment's "unused by every tenant" premise was false (D0.5: post_journal calls
-- next_number('JOURNAL_ENTRY', ...) unconditionally, and post_journal is called by create_sale,
-- create_sales_return, create_expense, create_voucher, reverse_journal, close_repair_job,
-- record_supplier_payment).
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

  -- ===== 2. NUMBER SERIES — the GOLDEN 10 (D1, 2026-07-16), tenant-level (branch_id NULL), padding 6. =====
  -- JOURNAL_ENTRY + RECEIPT_VOUCHER ADDED here (D1): the prior comment claiming they were "unused by
  -- every tenant" was false — post_journal calls next_number('JOURNAL_ENTRY', ...) unconditionally, and
  -- post_journal is called by create_sale/create_sales_return/create_expense/create_voucher/
  -- reverse_journal/close_repair_job/record_supplier_payment. Leaving them unseeded made next_number
  -- silently manufacture a junk document number (no type prefix) on first use (D0.4). SALES_RETURN is
  -- NOT a valid enum label (D0.1) — not added.
  -- STOCK_COUNT is the one Ahmad Store is missing — this insert is what closes that live drift.
  insert into number_series (tenant_id, branch_id, type, prefix, current_number)
  select p_tenant_id, null, v.type::number_series_type_enum, v.prefix, 0
  from (values
    ('INVOICE','INV-'), ('PURCHASE_ORDER','PO-'), ('GRN','GRN-'), ('STOCK_TRANSFER','TRF-'),
    ('STOCK_COUNT','SC-'), ('REPAIR_JOB','RJ-'), ('PAYMENT_VOUCHER','PV-'), ('PURCHASE_RETURN','PR-'),
    ('JOURNAL_ENTRY','JV-'), ('RECEIPT_VOUCHER','RV-')
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

  -- ===== 8. PAYMENT METHODS (§3.14) — 7 per tenant, unmapped (bank_account_id NULL -> resolver returns '1000').
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
end;
$function$
;
