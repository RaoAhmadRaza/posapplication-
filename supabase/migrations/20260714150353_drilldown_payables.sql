-- Payables KPI drilldown — the twin of drilldown_receivables, mirroring payables_aging()'s open-invoice set.
-- Tenant-scoped SECURITY DEFINER setof-json. purchase_invoices has no branch_id, so no branch param.
create or replace function public.drilldown_payables()
returns setof json language sql stable security definer set search_path to 'public' as $$
  select json_build_object('invoice_id', pi.id, 'supplier_id', pi.supplier_id,
    'supplier', coalesce(s.name, '—'), 'balance', pi.balance, 'status', pi.status, 'created_at', pi.created_at)
  from purchase_invoices pi join suppliers s on s.id=pi.supplier_id
  where pi.tenant_id=public.auth_tenant_id() and pi.deleted_at is null
    and pi.balance > 0 and pi.status <> 'VOID'
  order by pi.created_at desc;
$$;
