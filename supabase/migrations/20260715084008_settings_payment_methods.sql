-- ========== payment_methods — §3.14 VERBATIM ==========
create table if not exists public.payment_methods (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name varchar(100) not null,
  code varchar(50) not null,
  bank_account_id uuid references public.bank_accounts(id),
  is_active boolean not null default true,
  is_system boolean not null default false,
  requires_reference boolean not null default false,
  icon varchar(100),
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index if not exists uq_payment_methods_tenant_code on public.payment_methods(tenant_id, code) where deleted_at is null;
create index if not exists idx_payment_methods_tenant on public.payment_methods(tenant_id) where deleted_at is null and is_active;

alter table public.payment_methods enable row level security;
drop policy if exists "pm tenant read" on public.payment_methods;
create policy "pm tenant read" on public.payment_methods for select to authenticated using (tenant_id=public.auth_tenant_id());
drop policy if exists "pm gated write" on public.payment_methods;
create policy "pm gated write" on public.payment_methods for all to authenticated
  using (tenant_id=public.auth_tenant_id() and public.auth_has_permission('settings','update'))
  with check (tenant_id=public.auth_tenant_id() and public.auth_has_permission('settings','update'));

-- ========== SEED: one row per payment_method_enum label, per tenant. bank_account_id NULL = books to Cash. ==========
-- CASH is_system (cannot be deleted). Nothing maps to a bank account yet → resolver returns '1000' for all
-- → behaviour identical to today. The tenant opts into the split by linking a bank account in the UI (S6).
insert into public.payment_methods (tenant_id, name, code, is_system, requires_reference, sort_order)
select t.id, v.name, v.code, v.sys::boolean, v.ref::boolean, v.ord::int
from public.tenants t
cross join (values
  ('Cash','CASH','true','false','1'),
  ('Bank Transfer','BANK_TRANSFER','false','true','2'),
  ('Card','CARD','false','false','3'),
  ('Mobile Wallet','MOBILE_WALLET','false','true','4'),
  ('Cheque','CHEQUE','false','true','5'),
  ('Loyalty Points','LOYALTY_POINTS','false','false','6'),
  ('Credit Note','CREDIT_NOTE','false','true','7')
) as v(name,code,sys,ref,ord)
where not exists (select 1 from public.payment_methods pm where pm.tenant_id=t.id and pm.code=v.code and pm.deleted_at is null);

-- ========== THE SOLE RESOLVER — every money path calls this; nothing else picks a payment account. ==========
-- 3-tier resolution, schema chain: payment_methods.bank_account_id → bank_accounts.chart_account_id → accounts.code
--   1. explicit bank account named at payment time  → that bank account's GL account
--   2. else the method's linked bank account        → that bank account's GL account
--   3. else '1000' Cash                             → IDENTICAL TO TODAY (the safety fallback)
create or replace function public.resolve_payment_account(
  p_tenant_id uuid, p_method text, p_bank_account_id uuid
) returns varchar language plpgsql stable security definer set search_path to 'public' as $function$
declare v_code varchar;
begin
  -- tier 1: an explicit bank account on the payment wins
  if p_bank_account_id is not null then
    select a.code into v_code from bank_accounts ba join accounts a on a.id=ba.chart_account_id
      where ba.id=p_bank_account_id and ba.tenant_id=p_tenant_id and a.deleted_at is null;
    if v_code is not null then return v_code; end if;
  end if;
  -- tier 2: the method's configured bank account
  if p_method is not null then
    select a.code into v_code
      from payment_methods pm
      join bank_accounts ba on ba.id=pm.bank_account_id
      join accounts a on a.id=ba.chart_account_id
      where pm.tenant_id=p_tenant_id and pm.code=p_method and pm.deleted_at is null and pm.is_active
        and a.deleted_at is null;
    if v_code is not null then return v_code; end if;
  end if;
  -- tier 3: safety fallback = today's behaviour
  return '1000';
end; $function$;

-- ========== RLS cruft cleanup: bank_accounts has DUPLICATE select policies (S0 finding) ==========
drop policy if exists "bank tenant read" on public.bank_accounts;   -- keep "bank_accounts tenant read"