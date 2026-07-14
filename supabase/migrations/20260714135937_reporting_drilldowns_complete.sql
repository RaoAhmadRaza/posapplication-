-- The 4 sibling drilldowns promised (stubbed as a comment) in reporting_drilldowns. Same tenant-scoped
-- SECURITY DEFINER setof-json pattern as drilldown_sales; each mirrors the KPI it backs on the dashboard.

-- Low Stock KPI → below-reorder products (canonical stock, mirrors dashboard_summary low_stock logic)
create or replace function public.drilldown_low_stock(p_branch uuid default null)
returns setof json language sql stable security definer set search_path to 'public' as $$
  select json_build_object('product_id', sb.product_id, 'product_name', p.name, 'sku', p.sku,
    'qty_on_hand', sb.qty_on_hand, 'reorder_point', coalesce(sb.reorder_point, p.reorder_point, 0))
  from stock_balance sb join products p on p.id=sb.product_id and p.deleted_at is null
  where sb.tenant_id=public.auth_tenant_id() and sb.warehouse_id is null
    and (p_branch is null or sb.branch_id=p_branch)
    and sb.qty_on_hand <= coalesce(sb.reorder_point, p.reorder_point, 0)
  order by sb.qty_on_hand asc;
$$;

-- Receivables KPI → open customer invoices (mirrors dashboard_summary receivables: CONFIRMED/PARTIALLY_PAID)
create or replace function public.drilldown_receivables(p_branch uuid default null)
returns setof json language sql stable security definer set search_path to 'public' as $$
  select json_build_object('invoice_id', i.id, 'invoice_number', i.invoice_number, 'customer_id', i.customer_id,
    'customer', coalesce(c.name,'Walk-in'), 'balance', i.balance, 'status', i.status, 'created_at', i.created_at)
  from invoices i left join customers c on c.id=i.customer_id
  where i.tenant_id=public.auth_tenant_id() and i.deleted_at is null
    and i.status in ('CONFIRMED','PARTIALLY_PAID')
    and (p_branch is null or i.branch_id=p_branch)
  order by i.created_at desc;
$$;

-- Cash/Bank KPIs → the account's journal lines (by account_code, e.g. 1000/1010; tenant-scoped on both sides)
create or replace function public.drilldown_account(p_account_code varchar, p_from date default null, p_to date default null)
returns setof json language sql stable security definer set search_path to 'public' as $$
  select json_build_object('journal_entry_id', jl.journal_entry_id, 'entry_number', je.entry_number,
    'narration', jl.narration, 'description', je.description, 'debit', jl.debit, 'credit', jl.credit,
    'created_at', je.created_at)
  from journal_lines jl
    join journal_entries je on je.id=jl.journal_entry_id
    join accounts a on a.id=jl.account_id and a.tenant_id=public.auth_tenant_id()
  where je.tenant_id=public.auth_tenant_id() and a.code=p_account_code
    and je.created_at::date between coalesce(p_from, je.created_at::date) and coalesce(p_to, je.created_at::date)
  order by je.created_at desc;
$$;

-- Product KPI/row → that product's sales lines (mirrors drilldown_sales exclusions)
create or replace function public.drilldown_product(p_product uuid)
returns setof json language sql stable security definer set search_path to 'public' as $$
  select json_build_object('invoice_id', i.id, 'invoice_number', i.invoice_number, 'qty', ii.qty,
    'unit_price', ii.unit_price, 'line_total', ii.line_total, 'profit', ii.profit, 'created_at', i.created_at)
  from invoice_items ii join invoices i on i.id=ii.invoice_id
  where i.tenant_id=public.auth_tenant_id() and i.deleted_at is null
    and ii.product_id=p_product and i.status not in ('DRAFT','VOID')
  order by i.created_at desc;
$$;
