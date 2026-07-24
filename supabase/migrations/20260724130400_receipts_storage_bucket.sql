-- WhatsApp PDF receipt, part 5/6: private storage bucket for rendered receipt PDFs.
--
-- Mirrors the signatures bucket (20260713121820): PRIVATE, never public — receipts carry customer
-- name, line items and totals (financial PII). Path convention <tenant_id>/<invoice_id>.pdf.
--
-- The receipt-sender edge function writes and mints signed URLs as service_role, which BYPASSES RLS —
-- so no authenticated INSERT policy is granted (clients must never write receipts). A tenant-scoped
-- SELECT policy is added so the app can later fetch its own receipts (e.g. a "download" action);
-- reads stay signed-URL / RLS-gated to the owning tenant.

insert into storage.buckets (id, name, public) values ('receipts', 'receipts', false)
  on conflict (id) do nothing;

drop policy if exists "receipts read own tenant" on storage.objects;
create policy "receipts read own tenant" on storage.objects for select to authenticated
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = public.auth_tenant_id()::text);
