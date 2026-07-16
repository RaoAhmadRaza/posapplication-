-- D5: cron reproducibility. Rebuilding prod from migrations/ today yields a database with NO scheduled
-- work and nothing to say so — 7 jobs exist live in cron.job, zero in migrations/. Bug class #7 at the
-- infrastructure layer: a queue that fills and never empties, silently. Count grew 6->7 this session.
--
-- RECONCILED-BEFORE-PUSH (2026-07-16): dumped `select jobname, schedule, command, active from cron.job
-- order by jobname;` against prod first. All 7 below are pasted VERBATIM from that dump — schedules and
-- command bodies were hand-typed into the SQL editor over weeks; the docs were not the source of truth.
--
-- cron.schedule(job_name, schedule, command) is upsert-by-jobname (pg_cron), so this is idempotent and
-- safe to re-run without re-timing or re-bodying any job that already exists with the same name.

select cron.schedule(
  'approvals_escalation_hourly',
  '0 * * * *',
  $cron$select public.escalate_expired_approvals();$cron$
);

select cron.schedule(
  'mv_refresh_15min',
  '*/15 * * * *',
  $cron$select public.fn_refresh_materialized_views();$cron$
);

select cron.schedule(
  'notif_detectors_daily',
  '0 7 * * *',
  $cron$select public.fn_overdue_receivables_notify(); select public.fn_unpaid_salaries_notify(); select public.fn_stock_mismatch_notify();$cron$
);

select cron.schedule(
  'reorder_recommendations_daily',
  '0 6 * * *',
  $cron$select public.generate_reorder_recommendations();$cron$
);

select cron.schedule(
  'report_schedules_runner',
  '*/15 * * * *',
  $cron$select public.run_due_report_schedules();$cron$
);

select cron.schedule(
  'sync_outbox_drain_5min',
  '*/5 * * * *',
  $cron$ select public.sync_drain_cron(50); $cron$
);

select cron.schedule(
  'verify_provisioning_daily',
  '0 5 * * *',
  $cron$insert into notifications (tenant_id, user_id, title, body, channel, priority, status)
    select t.id, u.id, 'Provisioning incomplete', 'Tenant is missing required seeds', 'IN_APP','URGENT','DELIVERED'
    from tenants t
    join users u on u.tenant_id=t.id
    join roles r on r.id=u.role_id and r.name='ADMIN'
    where not ((public.verify_tenant_provisioning(t.id))->>'complete')::boolean
      and not exists (
        select 1 from notifications n
        where n.tenant_id=t.id and n.user_id=u.id and n.title='Provisioning incomplete'
          and n.created_at::date = current_date);$cron$
);
