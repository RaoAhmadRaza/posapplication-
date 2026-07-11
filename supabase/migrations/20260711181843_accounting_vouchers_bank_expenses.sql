-- ========== bank_accounts — verbatim §3.9 ==========
create table if not exists public.bank_accounts (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid references public.branches(id),
  account_name varchar(255) not null,
  bank_name varchar(255) not null,
  account_number varchar(100) not null,
  iban varchar(50),
  swift_code varchar(20),
  currency varchar(3) not null default 'PKR',
  opening_balance decimal(15,4) not null default 0,
  current_balance decimal(15,4) not null default 0,
  chart_account_id uuid references public.accounts(id),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  version integer not null default 1
);
create index if not exists idx_bank_accounts_tenant on public.bank_accounts(tenant_id) where deleted_at is null;
create index if not exists idx_bank_accounts_branch on public.bank_accounts(branch_id) where deleted_at is null;

-- ========== bank_reconciliations — verbatim §3.9 ==========
create table if not exists public.bank_reconciliations (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  bank_account_id uuid not null references public.bank_accounts(id),
  statement_date date not null,
  statement_balance decimal(15,4) not null,
  ledger_balance decimal(15,4) not null,
  reconciled_balance decimal(15,4),
  unreconciled_items_json jsonb,
  status reconciliation_status_enum not null default 'DRAFT',
  reconciled_by uuid references public.users(id),
  reconciled_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  version integer not null default 1
);
create index if not exists idx_bank_recon_account on public.bank_reconciliations(bank_account_id, statement_date);
create index if not exists idx_bank_recon_status on public.bank_reconciliations(tenant_id, status);

-- ========== expense_categories — verbatim §3.9 ==========
create table if not exists public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  name varchar(255) not null,
  account_id uuid not null references public.accounts(id),
  parent_id uuid references public.expense_categories(id),
  description text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create unique index if not exists uq_expense_categories_tenant_name on public.expense_categories(tenant_id, name) where deleted_at is null;
create index if not exists idx_expense_categories_account on public.expense_categories(account_id);

-- ========== expenses (line-level record; posts to journal). Styled to §3.9 conventions. ==========
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  branch_id uuid references public.branches(id),
  category_id uuid not null references public.expense_categories(id),
  expense_number varchar(50) not null,
  amount decimal(15,4) not null,
  tax_amount decimal(15,4) not null default 0,
  expense_date date not null default current_date,
  payment_method payment_method_enum not null,
  bank_account_id uuid references public.bank_accounts(id),
  reference varchar(255),
  description text,
  journal_entry_id uuid references public.journal_entries(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  version integer not null default 1,
  created_by uuid references public.users(id)
);
create index if not exists idx_expenses_tenant_date on public.expenses(tenant_id, expense_date) where deleted_at is null;
create index if not exists idx_expenses_category on public.expenses(category_id) where deleted_at is null;
do $$ begin alter table public.expenses add constraint chk_expenses_amount check (amount > 0); exception when duplicate_object then null; end $$;

-- ========== vouchers — verbatim §3.9 ==========
create table if not exists public.vouchers (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  voucher_number varchar(50) not null,
  type voucher_type_enum not null,
  journal_entry_id uuid references public.journal_entries(id),
  amount decimal(15,4) not null,
  party_type entity_type_enum,
  party_id uuid,
  bank_account_id uuid references public.bank_accounts(id),
  payment_method payment_method_enum,
  reference varchar(255),
  description text,
  approved_by uuid references public.users(id),
  approved_at timestamptz,
  correlation_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  version integer not null default 1,
  created_by uuid references public.users(id),
  updated_by uuid references public.users(id)
);
create unique index if not exists uq_vouchers_tenant_number on public.vouchers(tenant_id, voucher_number) where deleted_at is null;
create index if not exists idx_vouchers_type on public.vouchers(tenant_id, type) where deleted_at is null;
create index if not exists idx_vouchers_party on public.vouchers(party_type, party_id) where party_id is not null;
create index if not exists idx_vouchers_journal on public.vouchers(journal_entry_id) where journal_entry_id is not null;
do $$ begin alter table public.vouchers add constraint chk_vouchers_amount check (amount > 0); exception when duplicate_object then null; end $$;

-- ========== RLS: read tenant; writes via RPC (expense_categories client-CRUD gated accounting) ==========
do $$ declare tbl text; begin
  foreach tbl in array array['bank_accounts','bank_reconciliations','expenses','vouchers'] loop
    execute format('alter table public.%I enable row level security', tbl);
    execute format('drop policy if exists "%s tenant read" on public.%I', tbl, tbl);
    execute format('create policy "%s tenant read" on public.%I for select to authenticated using (tenant_id = public.auth_tenant_id())', tbl, tbl);
    execute format('revoke insert, update, delete on public.%I from authenticated', tbl);
  end loop;
end $$;

alter table public.expense_categories enable row level security;
drop policy if exists "ec tenant read" on public.expense_categories;
create policy "ec tenant read" on public.expense_categories for select to authenticated using (tenant_id = public.auth_tenant_id());
drop policy if exists "ec gated insert" on public.expense_categories;
create policy "ec gated insert" on public.expense_categories for insert to authenticated
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('accounting','create'));
drop policy if exists "ec gated update" on public.expense_categories;
create policy "ec gated update" on public.expense_categories for update to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('accounting','update'))
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('accounting','update'));

-- ========== bank_accounts client-CRUD gated accounting (master data like suppliers) ==========
drop policy if exists "bank tenant read" on public.bank_accounts;   -- replace the read-only policy set above for bank_accounts
create policy "bank tenant read" on public.bank_accounts for select to authenticated using (tenant_id = public.auth_tenant_id());
drop policy if exists "bank gated insert" on public.bank_accounts;
create policy "bank gated insert" on public.bank_accounts for insert to authenticated
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('accounting','create'));
drop policy if exists "bank gated update" on public.bank_accounts;
create policy "bank gated update" on public.bank_accounts for update to authenticated
  using (tenant_id = public.auth_tenant_id() and public.auth_has_permission('accounting','update'))
  with check (tenant_id = public.auth_tenant_id() and public.auth_has_permission('accounting','update'));

-- ========== RPC: create_voucher (manual payment/receipt/contra/journal → posts via post_journal) ==========
-- p_lines jsonb (same shape as post_journal). Creates the voucher + its journal entry atomically.
create or replace function public.create_voucher(
  p_branch_id uuid, p_type voucher_type_enum, p_amount numeric, p_party_type entity_type_enum,
  p_party_id uuid, p_bank_account_id uuid, p_payment_method payment_method_enum, p_reference varchar,
  p_description text, p_lines jsonb, p_date date default current_date
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_series number_series_type_enum; v_num text; v_je jsonb; v_je_id uuid; v_vid uuid;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'ERR_BAD_AMOUNT'; end if;

  v_series := case p_type when 'PAYMENT' then 'PAYMENT_VOUCHER' when 'RECEIPT' then 'RECEIPT_VOUCHER'
                          else 'JOURNAL_ENTRY' end::number_series_type_enum;
  v_num := public.next_number(v_series, p_branch_id);

  v_je := public.post_journal(p_branch_id, 'VOUCHER', null, coalesce(p_description, p_type::text||' voucher'),
                              p_lines, p_date, null, false);   -- p_gate=false: already gated above
  v_je_id := (v_je->>'journal_entry_id')::uuid;

  insert into vouchers (tenant_id, voucher_number, type, journal_entry_id, amount, party_type, party_id,
    bank_account_id, payment_method, reference, description, created_by, updated_by)
  values (v_t, v_num, p_type, v_je_id, round(p_amount,4), p_party_type, p_party_id, p_bank_account_id,
    p_payment_method, p_reference, p_description, v_uid, v_uid)
  returning id into v_vid;

  return jsonb_build_object('voucher_id', v_vid, 'voucher_number', v_num, 'journal_entry_id', v_je_id);
end; $function$;

-- ========== RPC: create_expense (records expense + posts Dr expense / Cr cash|bank) ==========
create or replace function public.create_expense(
  p_branch_id uuid, p_category_id uuid, p_amount numeric, p_tax_amount numeric, p_expense_date date,
  p_payment_method payment_method_enum, p_bank_account_id uuid, p_reference varchar, p_description text
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_acct_code varchar; v_exp_acct uuid; v_num text; v_je jsonb; v_je_id uuid; v_eid uuid; v_credit_code varchar; v_total numeric;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'ERR_BAD_AMOUNT'; end if;
  select a.code into v_acct_code from expense_categories ec join accounts a on a.id=ec.account_id
    where ec.id=p_category_id and ec.tenant_id=v_t;
  if not found then raise exception 'ERR_CATEGORY_NOT_FOUND'; end if;

  v_total := round(coalesce(p_amount,0) + coalesce(p_tax_amount,0), 4);
  v_credit_code := case when p_payment_method='CASH' then '1000' else '1010' end;  -- Cash / Bank
  v_num := public.next_number('PAYMENT_VOUCHER', p_branch_id);

  -- Dr expense (+ Dr input tax) / Cr cash|bank
  v_je := public.post_journal(p_branch_id, 'EXPENSE', null, coalesce(p_description,'Expense'),
    (case when coalesce(p_tax_amount,0) > 0 then
      jsonb_build_array(
        jsonb_build_object('account_code', v_acct_code, 'debit', round(p_amount,4), 'narration', p_description),
        jsonb_build_object('account_code', '1300', 'debit', round(p_tax_amount,4), 'narration','Input tax'),
        jsonb_build_object('account_code', v_credit_code, 'credit', v_total))
     else
      jsonb_build_array(
        jsonb_build_object('account_code', v_acct_code, 'debit', round(p_amount,4), 'narration', p_description),
        jsonb_build_object('account_code', v_credit_code, 'credit', v_total))
     end),
    coalesce(p_expense_date, current_date), null, false);
  v_je_id := (v_je->>'journal_entry_id')::uuid;

  insert into expenses (tenant_id, branch_id, category_id, expense_number, amount, tax_amount, expense_date,
    payment_method, bank_account_id, reference, description, journal_entry_id, created_by)
  values (v_t, p_branch_id, p_category_id, v_num, round(p_amount,4), round(coalesce(p_tax_amount,0),4),
    coalesce(p_expense_date,current_date), p_payment_method, p_bank_account_id, p_reference, p_description, v_je_id, v_uid)
  returning id into v_eid;

  -- maintain bank balance if paid from bank
  if p_bank_account_id is not null then
    update bank_accounts set current_balance = current_balance - v_total, updated_at=now() where id=p_bank_account_id;
  end if;

  return jsonb_build_object('expense_id', v_eid, 'expense_number', v_num, 'journal_entry_id', v_je_id, 'total', v_total);
end; $function$;