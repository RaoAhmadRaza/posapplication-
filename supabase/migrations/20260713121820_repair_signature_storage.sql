-- private bucket (never public); signed URLs only. Reconcile bucket-id/policy style to your existing buckets.
insert into storage.buckets (id, name, public) values ('signatures','signatures', false)
  on conflict (id) do nothing;

-- tenant-scoped read/write via RLS on storage.objects (path convention: <tenant_id>/<repair_id>.png)
drop policy if exists "sig read own tenant" on storage.objects;
create policy "sig read own tenant" on storage.objects for select to authenticated
  using (bucket_id='signatures' and (storage.foldername(name))[1] = public.auth_tenant_id()::text);
drop policy if exists "sig write own tenant" on storage.objects;
create policy "sig write own tenant" on storage.objects for insert to authenticated
  with check (bucket_id='signatures' and (storage.foldername(name))[1] = public.auth_tenant_id()::text
              and public.auth_has_permission('repair','update'));