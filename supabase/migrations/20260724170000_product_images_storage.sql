-- Product image uploads. Public bucket (catalog images aren't sensitive -> stable public URLs
-- served via CDN, no signed-URL churn in lists/POS grid). Writes are tenant-scoped by path prefix
-- '<tenant_id>/<product_id>/<file>' and gated on inventory:update, mirroring the signatures pattern.
insert into storage.buckets (id, name, public) values ('product-images', 'product-images', true)
  on conflict (id) do nothing;

drop policy if exists "product images tenant write"  on storage.objects;
drop policy if exists "product images tenant update"  on storage.objects;
drop policy if exists "product images tenant delete"  on storage.objects;

create policy "product images tenant write" on storage.objects for insert to authenticated
  with check (bucket_id = 'product-images'
    and (storage.foldername(name))[1] = public.auth_tenant_id()::text
    and public.auth_has_permission('inventory', 'update'));

create policy "product images tenant update" on storage.objects for update to authenticated
  using (bucket_id = 'product-images'
    and (storage.foldername(name))[1] = public.auth_tenant_id()::text
    and public.auth_has_permission('inventory', 'update'))
  with check (bucket_id = 'product-images'
    and (storage.foldername(name))[1] = public.auth_tenant_id()::text
    and public.auth_has_permission('inventory', 'update'));

create policy "product images tenant delete" on storage.objects for delete to authenticated
  using (bucket_id = 'product-images'
    and (storage.foldername(name))[1] = public.auth_tenant_id()::text
    and public.auth_has_permission('inventory', 'update'));
