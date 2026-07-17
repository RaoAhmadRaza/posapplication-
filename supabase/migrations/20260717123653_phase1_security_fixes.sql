-- Phase 1 — Security Fixes (ships alone, first). Basis: RUNBOOK v3 §1.
-- CRITICAL: closes self-role-escalation on public.users (diagnosis §7).
-- Idempotent: create-or-replace / drop-if-exists / is-distinct-from guards.

-- ===== 1.2  Helpers =====
create or replace function public.auth_role_id()
returns uuid language sql security definer stable set search_path = public as $$
  select u.role_id from public.users u where u.id = auth.uid();
$$;

-- case-normalized ADMIN test; the literal 'ADMIN' convention (handle_new_user +
-- the 7 seed_*_perms triggers) is preserved, this stops 'Admin'/'admin' slipping past.
create or replace function public.is_admin_role_name(p_name text)
returns boolean language sql immutable as $$
  select upper(trim(coalesce(p_name, ''))) = 'ADMIN';
$$;

-- DRIFT-PROOF subset gate: true only when the caller personally holds every granted
-- permission on p_role_id. Reads the permissions rows it protects, so it cannot rot.
create or replace function public.auth_can_grant_role(p_role_id uuid)
returns boolean language sql security definer stable set search_path = public as $$
  select not exists (
    select 1
    from public.permissions tp
    where tp.role_id = p_role_id
      and tp.granted = true
      and not exists (
        select 1
        from public.permissions mp
        join public.users u on u.role_id = mp.role_id
        where u.id = auth.uid()
          and mp.module = tp.module
          and mp.action = tp.action
          and mp.granted = true
      )
  );
$$;

revoke all on function public.auth_role_id() from public;
revoke all on function public.auth_can_grant_role(uuid) from public;
grant execute on function public.auth_role_id() to authenticated;
grant execute on function public.is_admin_role_name(text) to authenticated, anon;
grant execute on function public.auth_can_grant_role(uuid) to authenticated;

-- ===== 1.3  Fix self-escalation (CRITICAL) =====
-- STABLE definer helpers read the pre-update snapshot -> the new row must keep the
-- old tenant_id/role_id. Definer RPCs own the table (rls_forced=false) -> unaffected.
drop policy if exists "users update own" on public.users;
create policy "users update own"
on public.users for update to authenticated
using (auth.uid() = id)
with check (
  auth.uid() = id
  and tenant_id is not distinct from public.auth_tenant_id()
  and role_id   is not distinct from public.auth_role_id()
);

-- ===== 1.4  Column-level grants (defense in depth; 0.4: client only writes pin_hash,
-- plus profile fields) =====
revoke update on public.users from authenticated;
grant update (full_name, phone, avatar_url, pin_hash) on public.users to authenticated;

-- ===== 1.5A  Anon lock/unlock DoS: remove the custom counter surface =====
-- Supabase Auth rate-limits sign-in natively; client call sites deleted in the same change.
revoke execute on function public.increment_failed_login(text) from anon, public;
revoke execute on function public.reset_failed_login(text)     from anon, public;

-- ===== 1.6  provision_tenant() ownership =====
revoke execute on function public.provision_tenant(uuid) from public, anon;
grant execute on function public.provision_tenant(uuid) to authenticated;

-- provision_tenant() body below is the EXACT live definition with the 1.6 guard injected:
CREATE OR REPLACE FUNCTION public.provision_tenant(p_tenant_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_start date := date_trunc('year', current_date)::date; v_end date := (date_trunc('year', current_date) + interval '1 year - 1 day')::date;
begin
  -- 1.6 ownership guard: block authenticated cross-tenant calls. auth.uid() IS NULL
  -- during handle_new_user()'s signup trigger (no session, users row not yet created),
  -- so that path is exempt and MUST keep working (R1).
  if auth.uid() is not null and p_tenant_id is distinct from public.auth_tenant_id() then
    raise exception 'ERR_FORBIDDEN_TENANT';
  end if;
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
$function$;

-- ===== 1.9  Backfill hierarchy_level (BEFORE the 1.10 gate) =====
update public.roles set hierarchy_level = 1
where public.is_admin_role_name(name) and hierarchy_level is distinct from 1;

update public.roles set hierarchy_level = 5
where upper(trim(name)) = 'CASHIER' and hierarchy_level is distinct from 5;

update public.roles set hierarchy_level = 50
where not public.is_admin_role_name(name)
  and upper(trim(name)) <> 'CASHIER'
  and (hierarchy_level is null or hierarchy_level <= 5);

-- ===== 1.10  Keep hierarchy + ADMIN casing clean forward =====
create or replace function public.guard_role_hierarchy()
returns trigger language plpgsql set search_path = public as $$
begin
  if public.is_admin_role_name(new.name) and new.name <> 'ADMIN' then
    raise exception 'ERR_ADMIN_NAME_CASE: the admin role must be named exactly ADMIN';
  end if;
  if new.name = 'ADMIN' and new.hierarchy_level is distinct from 1 then
    raise exception 'ERR_ADMIN_HIERARCHY_FIXED: ADMIN must be level 1';
  end if;
  if not public.is_admin_role_name(new.name) and coalesce(new.hierarchy_level, 99) <= 1 then
    raise exception 'ERR_HIERARCHY_RESERVED: level 1 is reserved for ADMIN';
  end if;
  if new.hierarchy_level is null then
    raise exception 'ERR_HIERARCHY_REQUIRED';
  end if;
  return new;
end $$;

drop trigger if exists trg_guard_role_hierarchy on public.roles;
create trigger trg_guard_role_hierarchy
before insert or update on public.roles
for each row execute function public.guard_role_hierarchy();
