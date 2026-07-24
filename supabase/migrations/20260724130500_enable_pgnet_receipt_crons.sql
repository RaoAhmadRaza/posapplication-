-- WhatsApp PDF receipt, part 6/6: enable pg_net and schedule the delivery crons.
--
-- Runs AFTER the backlog quarantine (20260724130300) so the first tick sends nothing stale.
--
-- ┌─ MANUAL PREREQUISITE (do NOT put the key in a migration — it would leak into git history) ─┐
-- │ Before these jobs can authenticate, create the service-role key as a Vault secret ONCE via  │
-- │ the Supabase SQL editor / dashboard (out-of-band):                                          │
-- │                                                                                             │
-- │   select vault.create_secret('<SERVICE_ROLE_KEY>', 'service_role_key');                     │
-- │                                                                                             │
-- │ The cron command reads it at run time from vault.decrypted_secrets. Until the secret exists │
-- │ the jobs POST with a null bearer and the functions reject them (auth:["secret"]) — harmless,│
-- │ just no delivery. Scheduling here does not evaluate the command, so this migration is safe. │
-- └─────────────────────────────────────────────────────────────────────────────────────────────┘

create extension if not exists pg_net;

-- receipt-sender: renders the PDF, uploads it, sends the WhatsApp receipt. */2 min.
select cron.schedule(
  'receipt_sender_2min',
  '*/2 * * * *',
  $cron$
  select net.http_post(
    url := 'https://pwkmrjzksxwxypqmblel.supabase.co/functions/v1/receipt-sender',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key'),
      'Content-Type', 'application/json'),
    body := '{}'::jsonb);
  $cron$
);

-- notification-sender: drains the staff/customer SMS + email + report queues (finally). */2 min.
-- This is what revives repair-status notifications and scheduled report deliveries.
select cron.schedule(
  'notification_sender_2min',
  '*/2 * * * *',
  $cron$
  select net.http_post(
    url := 'https://pwkmrjzksxwxypqmblel.supabase.co/functions/v1/notification-sender',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || (select decrypted_secret from vault.decrypted_secrets where name = 'service_role_key'),
      'Content-Type', 'application/json'),
    body := '{}'::jsonb);
  $cron$
);
