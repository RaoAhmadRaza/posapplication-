-- ========== journal_entries + journal_lines — verbatim §3.9 (IMMUTABLE) ==========
create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  entry_number varchar(50) not null,
  reference_id uuid,
  reference_type varchar(50),
  description text not null,
  period_id uuid not null references public.fiscal_periods(id),
  branch_id uuid references public.branches(id),
  is_reversing boolean not null default false,
  reversed_entry_id uuid references public.journal_entries(id),
  posted_by uuid not null references public.users(id),
  correlation_id uuid,
  created_at timestamptz not null default now()
);
create unique index if not exists uq_journal_entries_tenant_number on public.journal_entries(tenant_id, entry_number);
create index if not exists idx_journal_entries_tenant_created on public.journal_entries(tenant_id, created_at);
create index if not exists idx_journal_entries_reference on public.journal_entries(reference_type, reference_id);
create index if not exists idx_journal_entries_period on public.journal_entries(period_id);
create index if not exists idx_journal_entries_correlation on public.journal_entries(correlation_id) where correlation_id is not null;

create table if not exists public.journal_lines (
  id uuid primary key default gen_random_uuid(),
  journal_entry_id uuid not null references public.journal_entries(id) on delete restrict,
  account_id uuid not null references public.accounts(id),
  debit decimal(15,4) not null default 0,
  credit decimal(15,4) not null default 0,
  narration text,
  branch_id uuid references public.branches(id),
  created_at timestamptz not null default now()
);
create index if not exists idx_journal_lines_entry on public.journal_lines(journal_entry_id);
create index if not exists idx_journal_lines_account on public.journal_lines(account_id, journal_entry_id);
create index if not exists idx_journal_lines_account_created on public.journal_lines(account_id, created_at);
do $$ begin alter table public.journal_lines add constraint chk_journal_lines_debit_positive check (debit >= 0); exception when duplicate_object then null; end $$;
do $$ begin alter table public.journal_lines add constraint chk_journal_lines_credit_positive check (credit >= 0); exception when duplicate_object then null; end $$;
do $$ begin alter table public.journal_lines add constraint chk_journal_lines_one_side check ((debit > 0 and credit = 0) or (debit = 0 and credit > 0)); exception when duplicate_object then null; end $$;

-- ========== RLS: read-only to client; writes via post_journal only ==========
alter table public.journal_entries enable row level security;
drop policy if exists "je tenant read" on public.journal_entries;
create policy "je tenant read" on public.journal_entries for select to authenticated using (tenant_id = public.auth_tenant_id());
revoke insert, update, delete on public.journal_entries from authenticated;

alter table public.journal_lines enable row level security;
drop policy if exists "jl tenant read" on public.journal_lines;
create policy "jl tenant read" on public.journal_lines for select to authenticated using (
  exists (select 1 from public.journal_entries je where je.id=journal_entry_id and je.tenant_id=public.auth_tenant_id()));
revoke insert, update, delete on public.journal_lines from authenticated;

-- ========== TRIGGER: fiscal period must be OPEN (verbatim schema §9.9) ==========
create or replace function public.fn_check_fiscal_period() returns trigger language plpgsql as $$
declare v_period_status fiscal_period_status_enum;
begin
  select status into v_period_status from public.fiscal_periods where id = NEW.period_id;
  if v_period_status is distinct from 'OPEN' then
    raise exception 'ERR_ACCOUNTING_PERIOD_CLOSED: Cannot post journal entry to % period', v_period_status
      using errcode='check_violation';
  end if;
  return NEW;
end $$;
drop trigger if exists trg_journal_check_period on public.journal_entries;
create trigger trg_journal_check_period before insert on public.journal_entries
  for each row execute function public.fn_check_fiscal_period();

-- ========== TRIGGER: journal_entries immutable (no update/delete; reversals via new entries) ==========
create or replace function public.fn_journal_immutable() returns trigger language plpgsql as $$
begin
  raise exception 'ERR_JOURNAL_IMMUTABLE: journal entries cannot be modified or deleted; post a reversing entry'
    using errcode='restrict_violation';
end $$;
drop trigger if exists trg_journal_immutable on public.journal_entries;
create trigger trg_journal_immutable before update or delete on public.journal_entries
  for each row execute function public.fn_journal_immutable();
drop trigger if exists trg_journal_lines_immutable on public.journal_lines;
create trigger trg_journal_lines_immutable before update or delete on public.journal_lines
  for each row execute function public.fn_journal_immutable();

-- ========== TRIGGER: entry must balance (SUM debit = SUM credit), checked at end of statement ==========
create or replace function public.fn_journal_balance_check() returns trigger language plpgsql as $$
declare v_d numeric; v_c numeric;
begin
  select coalesce(sum(debit),0), coalesce(sum(credit),0) into v_d, v_c
    from public.journal_lines where journal_entry_id = coalesce(NEW.journal_entry_id, NEW.id);
  if round(v_d,4) <> round(v_c,4) then
    raise exception 'ERR_JOURNAL_UNBALANCED: debits % <> credits %', v_d, v_c using errcode='check_violation';
  end if;
  return null;
end $$;
-- DEFERRED constraint trigger so it fires after all lines of a tx are inserted
drop trigger if exists trg_journal_balance_check on public.journal_lines;
create constraint trigger trg_journal_balance_check
  after insert on public.journal_lines
  deferrable initially deferred
  for each row execute function public.fn_journal_balance_check();

-- ========== post_journal: the ONLY writer. Balanced double-entry, atomic. ==========
-- p_lines jsonb array of {account_code, debit?, credit?, narration?}  (resolve code -> account_id)
create or replace function public.post_journal(
  p_branch_id uuid,
  p_reference_type varchar,
  p_reference_id uuid,
  p_description text,
  p_lines jsonb,
  p_date date default current_date,
  p_correlation_id uuid default null,
  p_gate boolean default true      -- auto-post callers pass false (already gated by the money RPC)
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_period uuid; v_num text; v_je uuid;
  v_line jsonb; v_acct uuid; v_d numeric; v_c numeric; v_sum_d numeric := 0; v_sum_c numeric := 0;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if p_gate and not public.auth_has_permission('accounting','create') then
    raise exception 'ERR_PERMISSION_DENIED' using errcode='42501';
  end if;
  if p_lines is null or jsonb_array_length(p_lines) < 2 then raise exception 'ERR_JOURNAL_MIN_TWO_LINES'; end if;

  v_period := public.current_fiscal_period(v_t, coalesce(p_date, current_date));
  v_num := public.next_number('JOURNAL_ENTRY', p_branch_id);

  insert into journal_entries (tenant_id, entry_number, reference_id, reference_type, description,
    period_id, branch_id, posted_by, correlation_id)
  values (v_t, v_num, p_reference_id, p_reference_type, p_description, v_period, p_branch_id, v_uid, p_correlation_id)
  returning id into v_je;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    v_acct := public.acct_id(v_t, (v_line->>'account_code'));
    if v_acct is null then raise exception 'ERR_ACCOUNT_NOT_FOUND: %', (v_line->>'account_code'); end if;
    v_d := round(coalesce((v_line->>'debit')::numeric,0),4);
    v_c := round(coalesce((v_line->>'credit')::numeric,0),4);
    if (v_d > 0 and v_c > 0) or (v_d = 0 and v_c = 0) then raise exception 'ERR_JOURNAL_LINE_ONE_SIDE'; end if;
    v_sum_d := v_sum_d + v_d; v_sum_c := v_sum_c + v_c;
    insert into journal_lines (journal_entry_id, account_id, debit, credit, narration, branch_id)
    values (v_je, v_acct, v_d, v_c, v_line->>'narration', p_branch_id);
    -- maintain account running balance (debit +, credit − by natural sign; report layer normalises by type)
    update accounts set current_balance = current_balance + v_d - v_c, updated_at = now() where id = v_acct;
  end loop;

  if round(v_sum_d,4) <> round(v_sum_c,4) then
    raise exception 'ERR_JOURNAL_UNBALANCED: debits % <> credits %', v_sum_d, v_sum_c using errcode='check_violation';
  end if;

  return jsonb_build_object('journal_entry_id', v_je, 'entry_number', v_num, 'total', v_sum_d);
end; $function$;

-- ========== reverse_journal: audit-safe correction (no deletes) ==========
create or replace function public.reverse_journal(p_entry_id uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_branch uuid; v_period uuid; v_num text; v_new uuid; v_orig_num text; v_line record;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('accounting','approve') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select branch_id, entry_number into v_branch, v_orig_num from journal_entries where id=p_entry_id and tenant_id=v_t;
  if not found then raise exception 'ERR_ENTRY_NOT_FOUND'; end if;
  if exists (select 1 from journal_entries where reversed_entry_id=p_entry_id) then raise exception 'ERR_ALREADY_REVERSED'; end if;

  v_period := public.current_fiscal_period(v_t, current_date);
  v_num := public.next_number('JOURNAL_ENTRY', v_branch);
  insert into journal_entries (tenant_id, entry_number, reference_type, description, period_id, branch_id,
    is_reversing, reversed_entry_id, posted_by)
  values (v_t, v_num, 'REVERSAL', 'Reversal of '||v_orig_num||': '||coalesce(p_reason,''), v_period, v_branch,
    true, p_entry_id, v_uid)
  returning id into v_new;

  for v_line in select account_id, debit, credit, narration, branch_id from journal_lines where journal_entry_id=p_entry_id loop
    insert into journal_lines (journal_entry_id, account_id, debit, credit, narration, branch_id)
    values (v_new, v_line.account_id, v_line.credit, v_line.debit, 'Reversal: '||coalesce(v_line.narration,''), v_line.branch_id);
    update accounts set current_balance = current_balance + v_line.credit - v_line.debit, updated_at=now() where id=v_line.account_id;
  end loop;
  return jsonb_build_object('reversal_entry_id', v_new, 'entry_number', v_num);
end; $function$;