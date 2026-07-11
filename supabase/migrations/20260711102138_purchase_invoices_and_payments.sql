-- ========== TABLES (verbatim §3.6). NOTE: bank_account_id has NO FK (bank_accounts = M07, not built). ==========
create table if not exists public.purchase_invoices (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  po_id uuid not null references public.purchase_orders(id),
  grn_id uuid references public.grns(id),
  supplier_id uuid not null references public.suppliers(id),
  supplier_invoice_number varchar(100),
  amount decimal(15,4) not null,
  tax_amount decimal(15,4) not null default 0,
  total_amount decimal(15,4) not null,
  paid_amount decimal(15,4) not null default 0,
  balance decimal(15,4) not null,
  status purchase_invoice_status_enum not null default 'DRAFT',
  due_date date,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  version integer not null default 1,
  created_by uuid references public.users(id),
  updated_by uuid references public.users(id)
);
create index if not exists idx_purchase_invoices_po       on public.purchase_invoices(po_id);
create index if not exists idx_purchase_invoices_supplier on public.purchase_invoices(supplier_id) where deleted_at is null;
create index if not exists idx_purchase_invoices_status   on public.purchase_invoices(tenant_id, status) where deleted_at is null;

create table if not exists public.supplier_payments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.tenants(id),
  supplier_id uuid not null references public.suppliers(id),
  invoice_id uuid references public.purchase_invoices(id),
  method payment_method_enum not null,
  amount decimal(15,4) not null,
  reference varchar(255),
  bank_account_id uuid,                    -- FK → bank_accounts deferred to M07
  voucher_number varchar(50),
  correlation_id uuid,
  notes text,
  paid_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  created_by uuid references public.users(id)
);
create index if not exists idx_supplier_payments_supplier on public.supplier_payments(supplier_id, paid_at);
create index if not exists idx_supplier_payments_invoice  on public.supplier_payments(invoice_id) where invoice_id is not null;
create index if not exists idx_supplier_payments_tenant   on public.supplier_payments(tenant_id, paid_at);
do $$ begin
  alter table public.supplier_payments add constraint chk_supplier_payments_amount check (amount > 0);
exception when duplicate_object then null; end $$;

-- ========== RLS: client read; writes via RPC ==========
alter table public.purchase_invoices enable row level security;
drop policy if exists "pinv tenant read" on public.purchase_invoices;
create policy "pinv tenant read" on public.purchase_invoices
  for select to authenticated using (tenant_id = public.auth_tenant_id());
revoke insert, update, delete on public.purchase_invoices from authenticated;

alter table public.supplier_payments enable row level security;
drop policy if exists "spay tenant read" on public.supplier_payments;
create policy "spay tenant read" on public.supplier_payments
  for select to authenticated using (tenant_id = public.auth_tenant_id());
revoke insert, update, delete on public.supplier_payments from authenticated;

-- ========== RPC: create_purchase_invoice (3-way match PO→GRN→Invoice) ==========
create or replace function public.create_purchase_invoice(
  p_po_id uuid, p_grn_id uuid, p_supplier_invoice_number varchar,
  p_amount numeric, p_tax_amount numeric, p_due_date date, p_notes text
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_supplier uuid; v_po_total numeric; v_total numeric; v_inv_id uuid; v_variance numeric;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  select supplier_id, grand_total into v_supplier, v_po_total
    from purchase_orders where id=p_po_id and tenant_id=v_t and deleted_at is null;
  if not found then raise exception 'ERR_PO_NOT_FOUND'; end if;
  if p_grn_id is not null and not exists (select 1 from grns where id=p_grn_id and po_id=p_po_id and tenant_id=v_t) then
    raise exception 'ERR_GRN_MISMATCH';    -- GRN must belong to this PO
  end if;
  if p_amount is null or p_amount < 0 then raise exception 'ERR_BAD_AMOUNT'; end if;

  v_total := round(coalesce(p_amount,0) + coalesce(p_tax_amount,0), 4);
  v_variance := round(v_total - coalesce(v_po_total,0), 4);   -- 3-way match variance (informational)

  insert into purchase_invoices (tenant_id, po_id, grn_id, supplier_id, supplier_invoice_number,
    amount, tax_amount, total_amount, paid_amount, balance, status, due_date, notes, created_by, updated_by)
  values (v_t, p_po_id, p_grn_id, v_supplier, nullif(p_supplier_invoice_number,''),
    round(coalesce(p_amount,0),4), round(coalesce(p_tax_amount,0),4), v_total, 0, v_total,
    'PENDING', p_due_date, p_notes, v_uid, v_uid)
  returning id into v_inv_id;

  update purchase_orders set status='INVOICED', updated_at=now(), version=version+1
    where id=p_po_id and status in ('RECEIVED','PARTIALLY_RECEIVED');

  return jsonb_build_object('invoice_id', v_inv_id, 'total_amount', v_total, 'match_variance', v_variance);
end; $function$;

-- ========== RPC: record_supplier_payment (full/partial) ==========
create or replace function public.record_supplier_payment(
  p_supplier_id uuid, p_invoice_id uuid, p_method payment_method_enum, p_amount numeric,
  p_reference varchar, p_bank_account_id uuid, p_notes text
) returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare
  v_t uuid := public.auth_tenant_id(); v_uid uuid := auth.uid();
  v_branch uuid; v_num text; v_pay_id uuid; v_bal numeric; v_paid numeric; v_total numeric;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('purchase','create') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'ERR_BAD_AMOUNT'; end if;
  if not exists (select 1 from suppliers where id=p_supplier_id and tenant_id=v_t) then raise exception 'ERR_SUPPLIER_NOT_FOUND'; end if;

  -- branch for voucher numbering: from the invoice's PO if present, else caller's first assigned branch
  if p_invoice_id is not null then
    select pi.balance, pi.paid_amount, pi.total_amount, po.branch_id
      into v_bal, v_paid, v_total, v_branch
      from purchase_invoices pi join purchase_orders po on po.id=pi.po_id
      where pi.id=p_invoice_id and pi.tenant_id=v_t and pi.deleted_at is null;
    if not found then raise exception 'ERR_INVOICE_NOT_FOUND'; end if;
    if p_amount > v_bal then raise exception 'ERR_OVERPAYMENT'; end if;
  else
    select branch_id into v_branch from user_branch_assignments where user_id=v_uid limit 1;
  end if;

  v_num := public.next_number('PAYMENT_VOUCHER', v_branch);

  insert into supplier_payments (tenant_id, supplier_id, invoice_id, method, amount, reference,
    bank_account_id, voucher_number, notes, created_by)
  values (v_t, p_supplier_id, p_invoice_id, p_method, round(p_amount,4), nullif(p_reference,''),
    p_bank_account_id, v_num, p_notes, v_uid)
  returning id into v_pay_id;

  if p_invoice_id is not null then
    update purchase_invoices
      set paid_amount = paid_amount + round(p_amount,4),
          balance     = balance - round(p_amount,4),
          status      = case when balance - round(p_amount,4) <= 0 then 'PAID' else status end,
          updated_at  = now(), version = version + 1
      where id = p_invoice_id;
  end if;

  return jsonb_build_object('payment_id', v_pay_id, 'voucher_number', v_num);
end; $function$;