-- WhatsApp PDF receipt, part 1/6: widen communication_logs for customer WhatsApp receipts.
--
-- Today channel is CHECK (channel in ('SMS','EMAIL')) — an insert with 'WHATSAPP' raises 23514,
-- so the create_sale enqueue (part 3) would silently no-op. Widen the CHECK. Also add:
--   - invoice_id: links a receipt row back to its sale (nullable — repair/report rows have none),
--   - attempts:   the sender is one-shot today; give receipt sends a retry budget,
--   - a partial UNIQUE index guaranteeing exactly one SALE_RECEIPT row per invoice
--     (defense-in-depth against a double-submit racing create_sale's idempotency guard).
-- All additive: widening a CHECK and adding nullable columns is backward-compatible; existing
-- SMS/EMAIL rows are unaffected.

alter table public.communication_logs
  drop constraint if exists communication_logs_channel_check;
alter table public.communication_logs
  add constraint communication_logs_channel_check
  check (channel in ('SMS', 'EMAIL', 'WHATSAPP'));

alter table public.communication_logs
  add column if not exists invoice_id uuid references public.invoices(id);
alter table public.communication_logs
  add column if not exists attempts int not null default 0;

-- Exactly one receipt per invoice. Predicate must match the ON CONFLICT arbiter in create_sale.
create unique index if not exists uq_comm_sale_receipt
  on public.communication_logs (invoice_id)
  where template_code = 'SALE_RECEIPT' and invoice_id is not null;

-- Sender queries receipt rows by (channel, template_code, status); index the drain path.
create index if not exists idx_comm_logs_receipt_pending
  on public.communication_logs (status, created_at)
  where channel = 'WHATSAPP' and template_code = 'SALE_RECEIPT';
