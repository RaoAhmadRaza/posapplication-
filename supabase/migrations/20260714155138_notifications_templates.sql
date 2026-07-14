-- ========== sms_templates — verbatim §3.13 ==========
create table if not exists public.sms_templates (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name varchar(255) not null,
  template_code varchar(100) not null,
  body text not null,
  language varchar(10) not null default 'en',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists uq_sms_templates on public.sms_templates(tenant_id, template_code, language);

-- ========== email_templates — verbatim §3.13 ==========
create table if not exists public.email_templates (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name varchar(255) not null,
  template_code varchar(100) not null,
  subject varchar(500) not null,
  body_html text not null,
  body_text text,
  language varchar(10) not null default 'en',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists uq_email_templates on public.email_templates(tenant_id, template_code, language);

-- ========== RLS: tenant read; notifications-gated write ==========
alter table public.sms_templates enable row level security;
drop policy if exists "smst read" on public.sms_templates;
create policy "smst read" on public.sms_templates for select to authenticated using (tenant_id=public.auth_tenant_id());
drop policy if exists "smst write" on public.sms_templates;
create policy "smst write" on public.sms_templates for all to authenticated
  using (tenant_id=public.auth_tenant_id() and public.auth_has_permission('notifications','update'))
  with check (tenant_id=public.auth_tenant_id() and public.auth_has_permission('notifications','update'));
alter table public.email_templates enable row level security;
drop policy if exists "emt read" on public.email_templates;
create policy "emt read" on public.email_templates for select to authenticated using (tenant_id=public.auth_tenant_id());
drop policy if exists "emt write" on public.email_templates;
create policy "emt write" on public.email_templates for all to authenticated
  using (tenant_id=public.auth_tenant_id() and public.auth_has_permission('notifications','update'))
  with check (tenant_id=public.auth_tenant_id() and public.auth_has_permission('notifications','update'));

-- ========== PERMISSION MODULE: notifications (mirror repair/hr) ==========
insert into public.permissions (role_id, module, action, branch_scope, granted)
select r.id, 'notifications', a.action, 'ALL', true
from public.roles r cross join (values ('read'),('create'),('update'),('delete'),('approve'),('export')) as a(action)
where r.name='ADMIN' on conflict (role_id, module, action) do nothing;
create or replace function public.seed_notifications_perms_for_admin()
returns trigger language plpgsql security definer set search_path to 'public' as $f$
begin
  if NEW.name='ADMIN' then
    insert into public.permissions (role_id, module, action, branch_scope, granted)
    select NEW.id, 'notifications', a.action, 'ALL', true
    from (values ('read'),('create'),('update'),('delete'),('approve'),('export')) as a(action)
    on conflict (role_id, module, action) do nothing;
  end if; return NEW;
end $f$;
drop trigger if exists trg_seed_notifications_perms on public.roles;
create trigger trg_seed_notifications_perms after insert on public.roles for each row execute function public.seed_notifications_perms_for_admin();

-- ========== SEED default templates per tenant (idempotent) — placeholders use {{var}} ==========
insert into public.sms_templates (tenant_id, name, template_code, body)
select t.id, v.name, v.code, v.body from public.tenants t
cross join (values
  ('Repair status','repair_status_update','Hi {{customer_name}}, your repair {{job_number}} is now {{status}}. - {{shop_name}}'),
  ('Payment reminder','payment_reminder','Reminder: PKR {{amount}} is due on invoice {{invoice_number}}. - {{shop_name}}'),
  ('Repair ready','repair_ready','Good news {{customer_name}}! Repair {{job_number}} is ready for pickup. - {{shop_name}}')
) as v(name,code,body)
where not exists (select 1 from public.sms_templates s where s.tenant_id=t.id and s.template_code=v.code and s.language='en');

insert into public.email_templates (tenant_id, name, template_code, subject, body_html, body_text)
select t.id, v.name, v.code, v.subject, v.html, v.txt from public.tenants t
cross join (values
  ('Scheduled report','scheduled_report','Your {{report_name}} report','<p>Attached/summary: {{report_name}} for {{period}}.</p>','{{report_name}} for {{period}}.'),
  ('Payment reminder','payment_reminder','Payment due: {{invoice_number}}','<p>PKR {{amount}} is due on {{invoice_number}}.</p>','PKR {{amount}} due on {{invoice_number}}.'),
  ('Repair status','repair_status_update','Repair {{job_number}} — {{status}}','<p>Hi {{customer_name}}, repair {{job_number}} is now {{status}}.</p>','Repair {{job_number}} is now {{status}}.')
) as v(name,code,subject,html,txt)
where not exists (select 1 from public.email_templates e where e.tenant_id=t.id and e.template_code=v.code and e.language='en');