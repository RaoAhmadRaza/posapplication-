alter table public.invoices add column if not exists idempotency_key uuid;
alter table public.invoices add column if not exists device_id uuid references devices(id) on delete set null;
alter table public.invoices add column if not exists local_ref text;      -- provisional receipt ref [SIGN-OFF #1(a)]

-- ⚠️ THE LAST LINE OF DEFENCE AGAINST A DOUBLE-POST. D4's guard is the fast path; this index cannot be raced.
-- Partial: every ONLINE sale leaves idempotency_key null, so uniqueness applies only where a key exists.
create unique index if not exists uq_invoices_idem on public.invoices(tenant_id, idempotency_key)
  where idempotency_key is not null;

-- Lets a customer's provisional paper receipt be FOUND once the real number is assigned [SIGN-OFF #1(a)].
create index if not exists idx_invoices_local_ref on public.invoices(tenant_id, local_ref) where local_ref is not null;

-- The index schema line ~1133 CLAIMS exists but D0.3 proved absent.
create index if not exists idx_invoices_offline on public.invoices(tenant_id, is_offline)
  where is_offline = true and synced_at is null;
