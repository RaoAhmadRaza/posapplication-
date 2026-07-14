-- Generic tenant-scoped drilldown reads (SECURITY DEFINER, filter auth_tenant_id()). One per KPI/summary.
-- Example: sales-of-a-day drilldown (tap a daily-sales cell → the invoices behind it)
create or replace function public.drilldown_sales(p_branch uuid, p_date date)
returns setof json language sql stable security definer set search_path to 'public' as $$
  select json_build_object('invoice_id', id, 'invoice_number', invoice_number, 'customer_id', customer_id,
    'grand_total', grand_total, 'status', status, 'created_at', created_at)
  from invoices where tenant_id=public.auth_tenant_id() and (p_branch is null or branch_id=p_branch)
    and date(created_at)=p_date and deleted_at is null and status not in ('DRAFT','VOID')
  order by created_at desc;
$$;
-- + drilldown_low_stock(), drilldown_receivables(customer bucket), drilldown_account(account_id → journal_lines),
--   drilldown_product(product_id → its invoice_items) — same tenant-filtered definer pattern.