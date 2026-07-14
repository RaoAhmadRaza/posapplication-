-- Fix fn_overdue_receivables_notify(): the overdue predicate was
--   current_date - (date(created_at) + make_interval(days => credit_terms)) > 0
-- which is (date - timestamp) => interval, compared to integer 0 => 42883 (no operator
-- interval > integer) at plan time, so the detector threw on every call regardless of data.
-- Compare day-counts directly: (today - invoice_date) > credit_terms. Body otherwise
-- byte-identical to the notifications_detectors definition.

create or replace function public.fn_overdue_receivables_notify()
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare v_n int:=0; r record;
begin
  for r in
    select i.tenant_id, i.customer_id, c.name as cust, sum(i.balance) as due
    from invoices i join customers c on c.id=i.customer_id
    where i.deleted_at is null and i.balance>0 and i.status not in ('DRAFT','VOID')
      and (current_date - date(i.created_at)) > coalesce(c.credit_terms,0)
    group by i.tenant_id, i.customer_id, c.name
  loop
    insert into notifications (tenant_id, user_id, title, body, channel, priority, status, action_type, action_id)
    select r.tenant_id, u.id, 'Overdue receivable', r.cust||' owes PKR '||r.due, 'IN_APP', 'HIGH', 'DELIVERED', 'customer', r.customer_id
    from users u join roles ro on ro.id=u.role_id
    where u.tenant_id=r.tenant_id and ro.name='ADMIN'
      and not exists (select 1 from notifications n where n.tenant_id=r.tenant_id and n.action_type='customer'
                        and n.action_id=r.customer_id and n.title='Overdue receivable' and n.created_at::date=current_date);
    v_n := v_n + 1;
  end loop;
  return jsonb_build_object('flagged', v_n);
end; $$;
