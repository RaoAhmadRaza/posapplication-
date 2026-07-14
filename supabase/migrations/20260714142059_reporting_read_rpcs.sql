-- Thin tenant-scoped read RPCs over the reporting matviews. Matviews aren't RLS-capable, so the client
-- MUST read them through these SECURITY DEFINER wrappers (filter auth_tenant_id() + reports:read), never raw.

create or replace function public.report_inventory_valuation()
returns setof json language sql stable security definer set search_path to 'public' as $$
  select json_build_object('product_id', product_id, 'product_name', product_name, 'sku', sku,
    'category_name', category_name, 'qty_on_hand', qty_on_hand, 'avg_cost', avg_cost,
    'total_value', total_value, 'selling_price', selling_price, 'retail_value', retail_value,
    'reorder_point', reorder_point, 'below_reorder', below_reorder, 'branch_id', branch_id)
  from mv_inventory_valuation
  where tenant_id = public.auth_tenant_id() and public.auth_has_permission('reports','read')
  order by total_value desc;
$$;

create or replace function public.report_product_performance()
returns setof json language sql stable security definer set search_path to 'public' as $$
  select json_build_object('product_id', product_id, 'product_name', product_name, 'sku', sku,
    'units_sold', units_sold, 'revenue', revenue, 'profit', profit,
    'invoice_count', invoice_count, 'last_sold_at', last_sold_at)
  from mv_product_performance
  where tenant_id = public.auth_tenant_id() and public.auth_has_permission('reports','read')
  order by revenue desc;
$$;

create or replace function public.report_customer_aging()
returns setof json language sql stable security definer set search_path to 'public' as $$
  select json_build_object('customer_id', customer_id, 'customer_name', customer_name,
    'total_balance', total_balance, 'bucket_current', bucket_current, 'bucket_1_30', bucket_1_30,
    'bucket_31_60', bucket_31_60, 'bucket_61_90', bucket_61_90, 'bucket_90_plus', bucket_90_plus,
    'max_days_overdue', max_days_overdue)
  from mv_customer_aging
  where tenant_id = public.auth_tenant_id() and public.auth_has_permission('reports','read')
  order by total_balance desc;
$$;

create or replace function public.report_supplier_aging()
returns setof json language sql stable security definer set search_path to 'public' as $$
  select json_build_object('supplier_id', supplier_id, 'supplier_name', supplier_name,
    'total_balance', total_balance, 'bucket_current', bucket_current, 'bucket_1_30', bucket_1_30,
    'bucket_31_60', bucket_31_60, 'bucket_61_90', bucket_61_90, 'bucket_90_plus', bucket_90_plus,
    'max_days_overdue', max_days_overdue)
  from mv_supplier_aging
  where tenant_id = public.auth_tenant_id() and public.auth_has_permission('reports','read')
  order by total_balance desc;
$$;

-- Trends: daily sales summary over an optional date range.
create or replace function public.report_daily_sales(p_from date default null, p_to date default null)
returns setof json language sql stable security definer set search_path to 'public' as $$
  select json_build_object('sale_date', sale_date, 'branch_id', branch_id, 'invoice_count', invoice_count,
    'customer_count', customer_count, 'total_revenue', total_revenue, 'total_profit', total_profit,
    'total_discounts', total_discounts, 'total_tax', total_tax, 'cash_sales', cash_sales,
    'credit_sales', credit_sales, 'return_count', return_count, 'return_amount', return_amount)
  from mv_daily_sales_summary
  where tenant_id = public.auth_tenant_id() and public.auth_has_permission('reports','read')
    and (p_from is null or sale_date >= p_from) and (p_to is null or sale_date <= p_to)
  order by sale_date;
$$;
