-- D1.3 — make next_number's silence audible. D0.4 proved (rolled back, live): calling next_number
-- for an unseeded type neither raises nor returns NULL — it silently inserts a default-configured
-- number_series row and returns a number off it ('BR01-000001', no type prefix — the worst of the
-- three predicted outcomes). SEPARATE MIGRATION from the seed backfill: next_number is not itself a
-- money RPC, but it is the sole gap-free counter used by every one of the 11 money-document paths in
-- the system (create_sale, create_sales_return, create_expense, create_voucher, post_journal, ...).
-- One RPC per migration. Minimum edit only: the self-heal insert becomes a raise; nothing else changes.
CREATE OR REPLACE FUNCTION public.next_number(p_type number_series_type_enum, p_branch_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_tenant uuid := public.auth_tenant_id(); v_row public.number_series; v_n int; v_code text := '';
begin
  if v_tenant is null then raise exception 'no tenant' using errcode='42501'; end if;
  select * into v_row from public.number_series
   where tenant_id=v_tenant and type=p_type
     and (branch_id = p_branch_id or branch_id is null)
   order by branch_id nulls last limit 1
   for update;
  if not found then
    raise exception 'ERR_NUMBER_SERIES_NOT_SEEDED: %', p_type;
  end if;
  v_n := v_row.current_number + 1;
  update public.number_series set current_number = v_n, updated_at = now() where id = v_row.id;
  if v_row.include_branch_code then
    select coalesce(code,'') into v_code from public.branches where id = p_branch_id;
    if v_code <> '' then v_code := v_code || '-'; end if;
  end if;
  return v_row.prefix || v_code || lpad(v_n::text, v_row.padding, '0') || v_row.suffix;
end;
$function$
;
