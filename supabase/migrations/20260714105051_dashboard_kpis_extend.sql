-- Extend dashboard_summary with payables_total + cash/bank balances + P&L snapshot.
-- Body = the live D0.1 dump VERBATIM; only the 4 new KPI computations + return fields added.
create or replace function public.dashboard_summary(p_branch_id uuid default null::uuid, p_from timestamp with time zone default null::timestamp with time zone, p_to timestamp with time zone default null::timestamp with time zone)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_t uuid := public.auth_tenant_id();
  v_from timestamptz := coalesce(p_from, date_trunc('day', now()));
  v_to   timestamptz := coalesce(p_to, now());
  v_sales numeric; v_txns int; v_profit numeric; v_recv numeric; v_stockval numeric; v_low int;
  v_recent jsonb; v_trend jsonb; v_pay jsonb;
  v_payables numeric; v_cash numeric; v_bank numeric; v_pl numeric;
begin
  if v_t is null then raise exception 'ERR_NO_TENANT' using errcode='42501'; end if;
  if not public.auth_has_permission('reports','read') then raise exception 'ERR_PERMISSION_DENIED' using errcode='42501'; end if;

  -- today (range) sales + txns  (exclude VOID/RETURNED)
  select coalesce(sum(grand_total),0), count(*) into v_sales, v_txns
  from invoices
  where tenant_id=v_t and (p_branch_id is null or branch_id=p_branch_id)
    and deleted_at is null and status not in ('VOID','RETURNED')
    and created_at >= v_from and created_at <= v_to;

  -- today profit
  select coalesce(sum(ii.profit),0) into v_profit
  from invoice_items ii join invoices i on i.id=ii.invoice_id
  where i.tenant_id=v_t and (p_branch_id is null or i.branch_id=p_branch_id)
    and i.deleted_at is null and i.status not in ('VOID','RETURNED')
    and i.created_at >= v_from and i.created_at <= v_to;

  -- receivables (all-time outstanding customer credit)
  select coalesce(sum(balance),0) into v_recv
  from invoices
  where tenant_id=v_t and (p_branch_id is null or branch_id=p_branch_id)
    and deleted_at is null and status in ('CONFIRMED','PARTIALLY_PAID');

  -- stock value + low stock
  select coalesce(sum(b.qty_on_hand*b.avg_cost),0) into v_stockval
  from stock_balance b
  where b.tenant_id=v_t and (p_branch_id is null or b.branch_id=p_branch_id);

  select count(*) into v_low
  from stock_balance b join products p on p.id=b.product_id
  where b.tenant_id=v_t and (p_branch_id is null or b.branch_id=p_branch_id)
    and p.deleted_at is null
    and b.qty_on_hand <= coalesce(b.reorder_point, p.reorder_point, 0);

  -- recent 5 sales
  select coalesce(jsonb_agg(x order by x_created desc),'[]'::jsonb) into v_recent from (
    select jsonb_build_object('invoice_number',i.invoice_number,'grand_total',i.grand_total,
             'status',i.status,'created_at',i.created_at,
             'customer', coalesce((select name from customers c where c.id=i.customer_id),'Walk-in')) as x,
           i.created_at as x_created
    from invoices i
    where i.tenant_id=v_t and (p_branch_id is null or i.branch_id=p_branch_id) and i.deleted_at is null
    order by i.created_at desc limit 5
  ) q;

  -- 7-day sales trend (incl today)
  select coalesce(jsonb_agg(jsonb_build_object('day', d::date, 'total', coalesce(s.total,0)) order by d),'[]'::jsonb)
  into v_trend
  from generate_series(date_trunc('day',now())-interval '6 days', date_trunc('day',now()), interval '1 day') d
  left join (
    select date_trunc('day',created_at) dd, sum(grand_total) total
    from invoices
    where tenant_id=v_t and (p_branch_id is null or branch_id=p_branch_id)
      and deleted_at is null and status not in ('VOID','RETURNED')
      and created_at >= date_trunc('day',now())-interval '6 days'
    group by 1
  ) s on s.dd = d;

  -- payment method breakdown (range)
  select coalesce(jsonb_object_agg(method, amt),'{}'::jsonb) into v_pay from (
    select p.method::text as method, sum(p.amount) amt
    from payments p join invoices i on i.id=p.invoice_id
    where i.tenant_id=v_t and (p_branch_id is null or i.branch_id=p_branch_id)
      and i.deleted_at is null and p.created_at >= v_from and p.created_at <= v_to
    group by p.method
  ) z;

  -- payables (mirror live payables_aging: open supplier balances, no branch dim on purchase_invoices)
  select coalesce(sum(balance),0) into v_payables
  from purchase_invoices
  where tenant_id=v_t and deleted_at is null and balance > 0 and status <> 'VOID';

  -- cash (1000) + bank (1010) from the ledger MV
  select coalesce(sum(balance) filter (where account_code='1000'),0),
         coalesce(sum(balance) filter (where account_code='1010'),0)
    into v_cash, v_bank
  from mv_account_balances
  where tenant_id=v_t and (p_branch_id is null or branch_id=p_branch_id);

  -- P&L snapshot from the ledger MV: revenue (4xxx) − expenses (5xxx/6xxx).
  -- balance = debit−credit, so revenue (credit-normal) and expense both negate to revenue−expenses.
  select coalesce(sum(-balance),0) into v_pl
  from mv_account_balances
  where tenant_id=v_t and (p_branch_id is null or branch_id=p_branch_id)
    and (account_code like '4%' or account_code like '5%' or account_code like '6%');

  return jsonb_build_object(
    'today_sales',v_sales,'today_txns',v_txns,'today_profit',v_profit,
    'receivables',v_recv,'stock_value',v_stockval,'low_stock_count',v_low,
    'recent_sales',v_recent,'sales_trend',v_trend,'payment_breakdown',v_pay,
    'payables_total',v_payables,'cash_balance',v_cash,'bank_balance',v_bank,'pl_snapshot',v_pl,
    'from',v_from,'to',v_to);
end; $function$;
