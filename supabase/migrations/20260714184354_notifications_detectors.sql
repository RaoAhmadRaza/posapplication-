-- overdue receivables → notify the tenant's ADMINs (one per day per customer). Reuse the aging logic.
create or replace function public.fn_overdue_receivables_notify()
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_n int:=0; r record;
begin
  for r in
    select i.tenant_id, i.customer_id, c.name as cust, sum(i.balance) as due
    from invoices i join customers c on c.id=i.customer_id
    where i.deleted_at is null and i.balance>0 and i.status not in ('DRAFT','VOID')
      and (current_date - (date(i.created_at) + make_interval(days => coalesce(c.credit_terms,0)))) > 0
    group by i.tenant_id, i.customer_id, c.name
  loop
    -- notify each admin user of that tenant (idempotent per day via metadata dedupe is app-side; keep simple here)
    insert into notifications (tenant_id, user_id, title, body, channel, priority, status, action_type, action_id)
    select r.tenant_id, u.id, 'Overdue receivable', r.cust||' owes PKR '||r.due, 'IN_APP', 'HIGH', 'DELIVERED', 'customer', r.customer_id
    from users u join roles ro on ro.id=u.role_id
    where u.tenant_id=r.tenant_id and ro.name='ADMIN'
      and not exists (select 1 from notifications n where n.tenant_id=r.tenant_id and n.action_type='customer'
                        and n.action_id=r.customer_id and n.title='Overdue receivable' and n.created_at::date=current_date);
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('flagged', v_n);
end; $function$;

-- unpaid salaries: an APPROVED payroll_run not yet DISBURSED past period_end → nudge finance.
create or replace function public.fn_unpaid_salaries_notify()
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_n int:=0; r record;
begin
  for r in select tenant_id, id, period from payroll_runs where status='APPROVED' and period_end < current_date loop
    insert into notifications (tenant_id, user_id, title, body, channel, priority, status, action_type, action_id)
    select r.tenant_id, u.id, 'Payroll pending disbursement', 'Approved payroll '||r.period||' not yet disbursed', 'IN_APP','HIGH','DELIVERED','payroll_run', r.id
    from users u join roles ro on ro.id=u.role_id where u.tenant_id=r.tenant_id and ro.name='ADMIN'
      and not exists (select 1 from notifications n where n.action_type='payroll_run' and n.action_id=r.id and n.created_at::date=current_date);
    v_n:=v_n+1;
  end loop;
  return jsonb_build_object('flagged', v_n);
end; $function$;

-- stock mismatch: qty_on_hand < 0 (impossible-but-guard) or reserved > on_hand → data-integrity alert.
create or replace function public.fn_stock_mismatch_notify()
returns jsonb language plpgsql security definer set search_path to 'public' as $function$
declare v_n int:=0; r record;
begin
  for r in select tenant_id, product_id from stock_balance where warehouse_id is null and (qty_on_hand < 0 or qty_reserved > qty_on_hand) loop
    insert into notifications (tenant_id, user_id, title, body, channel, priority, status, action_type, action_id)
    select r.tenant_id, u.id, 'Stock mismatch', 'Product '||r.product_id||' has an inconsistent balance', 'IN_APP','URGENT','DELIVERED','product', r.product_id
    from users u join roles ro on ro.id=u.role_id where u.tenant_id=r.tenant_id and ro.name='ADMIN'
      and not exists (select 1 from notifications n where n.action_type='product' and n.action_id=r.product_id and n.title='Stock mismatch' and n.created_at::date=current_date);
    v_n:=v_n+1;
  end loop;
  return jsonb_build_object('flagged', v_n);
end; $function$;
-- (pending transfers detector: mirror — flag TRANSFER stock movements awaiting receipt. Same pattern.)