-- ===== 8.1 daily sales — FAN-OUT FIXED: invoice-level totals and item-level profit aggregated SEPARATELY =====
create materialized view if not exists public.mv_daily_sales_summary as
with inv as (
  select tenant_id, branch_id, date(created_at) as sale_date,
         count(*) as invoice_count, count(distinct customer_id) as customer_count,
         sum(grand_total) as total_revenue, sum(discount_total) as total_discounts, sum(tax_total) as total_tax,
         sum(case when sale_type='CASH' then grand_total else 0 end) as cash_sales,
         sum(case when sale_type='CREDIT' then grand_total else 0 end) as credit_sales,
         count(*) filter (where status='RETURNED') as return_count,
         sum(case when status='RETURNED' then grand_total else 0 end) as return_amount
  from invoices where deleted_at is null and status not in ('DRAFT','VOID')
  group by tenant_id, branch_id, date(created_at)
), prof as (
  select i.tenant_id, i.branch_id, date(i.created_at) as sale_date, sum(ii.profit) as total_profit
  from invoices i join invoice_items ii on ii.invoice_id=i.id
  where i.deleted_at is null and i.status not in ('DRAFT','VOID')
  group by i.tenant_id, i.branch_id, date(i.created_at)
)
select inv.*, coalesce(prof.total_profit,0) as total_profit
from inv left join prof using (tenant_id, branch_id, sale_date);
create unique index if not exists uq_mv_daily_sales on public.mv_daily_sales_summary(tenant_id, branch_id, sale_date);

-- ===== 8.2 inventory valuation — CANONICAL stock only (warehouse_id IS NULL); one row per (tenant,branch,product) =====
create materialized view if not exists public.mv_inventory_valuation as
select sb.tenant_id, sb.branch_id, sb.product_id, p.name as product_name, p.sku, c.name as category_name,
       sb.qty_on_hand, sb.qty_reserved, sb.qty_in_transit, sb.avg_cost,
       (sb.qty_on_hand * sb.avg_cost) as total_value, p.selling_price,
       (sb.qty_on_hand * p.selling_price) as retail_value, p.reorder_point,
       (sb.qty_on_hand <= p.reorder_point) as below_reorder
from stock_balance sb
join products p on p.id=sb.product_id and p.deleted_at is null
left join categories c on c.id=p.category_id
where sb.warehouse_id is null                                    -- canonical only (avoids variant/warehouse fan-out)
  and (sb.qty_on_hand <> 0 or sb.qty_reserved <> 0 or sb.qty_in_transit <> 0);
create unique index if not exists uq_mv_inventory on public.mv_inventory_valuation(tenant_id, branch_id, product_id);

-- ===== 8.3 account balances — accounts.branch_id CONFIRMED LIVE (D0), so keep it =====
create materialized view if not exists public.mv_account_balances as
select a.tenant_id, a.id as account_id, a.code as account_code, a.name as account_name, a.type as account_type,
       a.branch_id,
       coalesce(sum(jl.debit),0) as total_debit, coalesce(sum(jl.credit),0) as total_credit,
       coalesce(sum(jl.debit),0) - coalesce(sum(jl.credit),0) as balance
from accounts a
left join journal_lines jl on jl.account_id=a.id
where a.deleted_at is null
group by a.tenant_id, a.id, a.code, a.name, a.type, a.branch_id;
create unique index if not exists uq_mv_account_balances on public.mv_account_balances(tenant_id, account_id);

-- ===== 8.4 customer aging — mirrors live receivables_aging() buckets; one row per (tenant,customer) =====
create materialized view if not exists public.mv_customer_aging as
with open_inv as (
  select i.tenant_id, i.customer_id, c.name as customer_name,
    greatest(i.balance, 0) as balance,
    greatest(0, (current_date - (i.created_at::date + (coalesce(c.credit_terms,0) || ' days')::interval)::date)) as days_overdue
  from invoices i join customers c on c.id=i.customer_id
  where i.status <> 'VOID' and i.customer_id is not null and greatest(i.balance, 0) > 0
)
select tenant_id, customer_id, customer_name,
  sum(balance) as total_balance,
  sum(balance) filter (where days_overdue = 0) as bucket_current,
  sum(balance) filter (where days_overdue between 1 and 30) as bucket_1_30,
  sum(balance) filter (where days_overdue between 31 and 60) as bucket_31_60,
  sum(balance) filter (where days_overdue between 61 and 90) as bucket_61_90,
  sum(balance) filter (where days_overdue > 90) as bucket_90_plus,
  max(days_overdue) as max_days_overdue
from open_inv group by tenant_id, customer_id, customer_name;
create unique index if not exists uq_mv_customer_aging on public.mv_customer_aging(tenant_id, customer_id);

-- ===== 8.5 supplier aging — mirrors live payables_aging() buckets; one row per (tenant,supplier) =====
create materialized view if not exists public.mv_supplier_aging as
with open_inv as (
  select pi.tenant_id, pi.supplier_id, s.name as supplier_name, pi.balance,
    greatest(0, (current_date - coalesce(pi.due_date, pi.created_at::date))) as days_overdue
  from purchase_invoices pi join suppliers s on s.id=pi.supplier_id
  where pi.deleted_at is null and pi.balance > 0 and pi.status <> 'VOID'
)
select tenant_id, supplier_id, supplier_name,
  sum(balance) as total_balance,
  sum(balance) filter (where days_overdue = 0) as bucket_current,
  sum(balance) filter (where days_overdue between 1 and 30) as bucket_1_30,
  sum(balance) filter (where days_overdue between 31 and 60) as bucket_31_60,
  sum(balance) filter (where days_overdue between 61 and 90) as bucket_61_90,
  sum(balance) filter (where days_overdue > 90) as bucket_90_plus,
  max(days_overdue) as max_days_overdue
from open_inv group by tenant_id, supplier_id, supplier_name;
create unique index if not exists uq_mv_supplier_aging on public.mv_supplier_aging(tenant_id, supplier_id);

-- ===== 8.6 product performance — units/revenue/profit per product over a trailing window =====
create materialized view if not exists public.mv_product_performance as
select i.tenant_id, ii.product_id, p.name as product_name, p.sku,
       sum(ii.qty) as units_sold, sum(ii.line_total) as revenue, sum(ii.profit) as profit,
       count(distinct i.id) as invoice_count, max(i.created_at) as last_sold_at
from invoice_items ii
join invoices i on i.id=ii.invoice_id and i.deleted_at is null and i.status not in ('DRAFT','VOID')
join products p on p.id=ii.product_id
group by i.tenant_id, ii.product_id, p.name, p.sku;
create unique index if not exists uq_mv_product_performance on public.mv_product_performance(tenant_id, product_id);

-- ===== refresh function (CONCURRENTLY needs the unique indexes above) =====
create or replace function public.fn_refresh_materialized_views()
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  refresh materialized view concurrently public.mv_daily_sales_summary;
  refresh materialized view concurrently public.mv_inventory_valuation;
  refresh materialized view concurrently public.mv_account_balances;
  refresh materialized view concurrently public.mv_customer_aging;
  refresh materialized view concurrently public.mv_supplier_aging;
  refresh materialized view concurrently public.mv_product_performance;
end; $$;

-- RLS note: matviews don't take RLS. Reads MUST go through SECURITY DEFINER RPCs that filter tenant_id =
-- auth_tenant_id(), OR expose tenant-filtered wrapper views. Do NOT grant raw matview select to authenticated.
revoke all on public.mv_daily_sales_summary, public.mv_inventory_valuation, public.mv_account_balances,
  public.mv_customer_aging, public.mv_supplier_aging, public.mv_product_performance from authenticated;
