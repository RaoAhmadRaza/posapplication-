-- next_number returned NULL for any series with include_branch_code = true when
-- called with a null branch (e.g. BANK_OPENING journal, which posts with no branch):
--   SELECT coalesce(code,'') INTO v_code FROM branches WHERE id = <null>
-- matches zero rows, and PL/pgSQL sets v_code to NULL on no-row SELECT INTO — so the
-- final `prefix || v_code || lpad(...)` collapsed to NULL and journal_entries.entry_number
-- (not null) rejected the row. Vouchers/expenses were unaffected only because they pass a
-- real branch_id. Root-cause fix: skip the branch-code lookup when p_branch_id is null.
create or replace function public.next_number(p_type number_series_type_enum, p_branch_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); v_row public.number_series; v_n int; v_code text := '';
begin
  if v_tenant is null then raise exception 'no tenant' using errcode='42501'; end if;
  select * into v_row from public.number_series
   where tenant_id=v_tenant and type=p_type
     and (branch_id = p_branch_id or branch_id is null)
   order by branch_id nulls last limit 1
   for update;
  if not found then
    insert into public.number_series (tenant_id, branch_id, type) values (v_tenant, p_branch_id, p_type)
    returning * into v_row;
  end if;
  v_n := v_row.current_number + 1;
  update public.number_series set current_number = v_n, updated_at = now() where id = v_row.id;
  if v_row.include_branch_code and p_branch_id is not null then
    select coalesce(code,'') into v_code from public.branches where id = p_branch_id;
    if v_code <> '' then v_code := v_code || '-'; end if;
  end if;
  return v_row.prefix || v_code || lpad(v_n::text, v_row.padding, '0') || v_row.suffix;
end; $$;
