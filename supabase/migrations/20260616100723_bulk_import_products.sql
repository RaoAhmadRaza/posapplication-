-- <timestamp>_bulk_import_products.sql
create or replace function public.bulk_import_products(p_rows jsonb)
-- p_rows: [{name, barcode, category_name, brand_name, cost_price, selling_price, unit_of_measure}]
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); r jsonb; v_cat uuid; v_brand uuid;
        v_ok int := 0; v_fail int := 0; v_errors jsonb := '[]'::jsonb; v_i int := 0;
begin
  if v_tenant is null then raise exception 'no tenant' using errcode='42501'; end if;
  if not public.auth_has_permission('inventory','create') then raise exception 'permission denied' using errcode='42501'; end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    v_i := v_i + 1;
    begin
      if coalesce(trim(r->>'name'),'') = '' then raise exception 'name required'; end if;
      -- resolve or create category/brand by name (optional)
      v_cat := null; v_brand := null;
      if coalesce(r->>'category_name','') <> '' then
        select id into v_cat from public.categories where tenant_id=v_tenant and lower(name)=lower(r->>'category_name') and deleted_at is null limit 1;
      end if;
      if coalesce(r->>'brand_name','') <> '' then
        select id into v_brand from public.brands where tenant_id=v_tenant and lower(name)=lower(r->>'brand_name') and deleted_at is null limit 1;
      end if;
      insert into public.products (tenant_id, name, barcode, category_id, brand_id, unit_of_measure, cost_price, selling_price, created_by, updated_by)
      values (v_tenant, trim(r->>'name'), nullif(r->>'barcode',''), v_cat, v_brand,
              coalesce(nullif(r->>'unit_of_measure',''),'PCS'),
              coalesce((r->>'cost_price')::numeric,0), coalesce((r->>'selling_price')::numeric,0),
              auth.uid(), auth.uid());
      v_ok := v_ok + 1;
    exception when others then
      v_fail := v_fail + 1;
      v_errors := v_errors || jsonb_build_object('row', v_i, 'error', SQLERRM);
    end;
  end loop;
  return jsonb_build_object('ok', v_ok, 'failed', v_fail, 'errors', v_errors);
end; $$;
revoke all on function public.bulk_import_products(jsonb) from anon, public;
grant execute on function public.bulk_import_products(jsonb) to authenticated;