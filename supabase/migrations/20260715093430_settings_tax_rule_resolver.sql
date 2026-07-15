-- Settings S4: make tax_rules authoritative at DATA-ENTRY time (product defaults / POS line defaults).
-- NOT at posting time — create_sale still takes caller-supplied p_tax_pct, so no invoice totals move.
-- resolve_tax_rate: product override wins, else the tenant's is_default rule, else 0.
create or replace function public.resolve_tax_rate(p_tenant_id uuid, p_product_id uuid)
returns jsonb language plpgsql stable security definer set search_path to 'public' as $function$
declare v_rate numeric; v_mode text; v_code text;
begin
  -- product override wins if set (products.tax_rate is NOT NULL today)
  if p_product_id is not null then
    select tax_rate into v_rate from products where id=p_product_id and tenant_id=p_tenant_id and deleted_at is null;
    if v_rate is not null then return jsonb_build_object('rate', v_rate, 'source', 'product'); end if;
  end if;
  -- else the tenant's default rule (applies_to scoping is a future extension — flagged)
  select rate, mode, code into v_rate, v_mode, v_code from tax_rules
    where tenant_id=p_tenant_id and is_default and deleted_at is null and coalesce(is_active,true) limit 1;
  if v_rate is null then return jsonb_build_object('rate', 0, 'source', 'none'); end if;
  return jsonb_build_object('rate', v_rate, 'mode', v_mode, 'code', v_code, 'source', 'tax_rule');
end; $function$;
