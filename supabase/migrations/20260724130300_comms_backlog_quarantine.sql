-- WhatsApp PDF receipt, part 4/6: quarantine the stale delivery backlog.
--
-- Nothing has ever drained the comms queues (the senders were never triggered — delivery was
-- deferred to "M11"). So every communication_logs / report_deliveries / notifications row ever
-- enqueued still sits at PENDING. The moment part 6 wires a cron, the senders would blast MONTHS of
-- stale messages (old repair-status texts, old report emails, old alerts) to real recipients.
--
-- Quarantine BEFORE any cron exists: flip existing PENDING rows to FAILED with a marker so they are
-- never sent. Going forward, only rows created after this migration (fresh) will be delivered — the
-- senders also apply a created_at freshness window as defense-in-depth.
--
-- NOTE ordering: this runs before 20260724130500 (pg_net + cron). Do NOT reorder.
-- Status domains: communication_logs.status = text CHECK(PENDING/QUEUED/SENT/FAILED);
-- report_deliveries.status = free text; notifications.status = enum(PENDING/SENT/DELIVERED/READ/FAILED).
-- 'FAILED' is valid in all three.

update public.communication_logs
  set status = 'FAILED', error = 'backlog quarantine 2026-07-24 (pre-cron)'
  where status = 'PENDING';

update public.report_deliveries
  set status = 'FAILED', error = 'backlog quarantine 2026-07-24 (pre-cron)'
  where status = 'PENDING';

update public.notifications
  set status = 'FAILED'
  where status = 'PENDING' and channel in ('SMS', 'EMAIL', 'WHATSAPP', 'PUSH');
