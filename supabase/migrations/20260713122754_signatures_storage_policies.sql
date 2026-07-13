-- Private 'signatures' bucket access control. The bucket exists (private); it had NO RLS policies, so
-- the client could neither upload nor read. Tenant-scoped by path prefix '<tenant_id>/<repair_id>.png'
-- ((storage.foldername(name))[1] = the tenant), and repair-permission gated: write needs repair:update,
-- read needs repair:read. Objects stay private — access only via short-lived signed URLs.
drop policy if exists "signatures tenant read" on storage.objects;
drop policy if exists "signatures tenant write" on storage.objects;
drop policy if exists "signatures tenant update" on storage.objects;

create policy "signatures tenant read" on storage.objects for select to authenticated
  using (bucket_id = 'signatures'
    and (storage.foldername(name))[1] = public.auth_tenant_id()::text
    and public.auth_has_permission('repair','read'));

create policy "signatures tenant write" on storage.objects for insert to authenticated
  with check (bucket_id = 'signatures'
    and (storage.foldername(name))[1] = public.auth_tenant_id()::text
    and public.auth_has_permission('repair','update'));

create policy "signatures tenant update" on storage.objects for update to authenticated
  using (bucket_id = 'signatures'
    and (storage.foldername(name))[1] = public.auth_tenant_id()::text
    and public.auth_has_permission('repair','update'))
  with check (bucket_id = 'signatures'
    and (storage.foldername(name))[1] = public.auth_tenant_id()::text
    and public.auth_has_permission('repair','update'));
