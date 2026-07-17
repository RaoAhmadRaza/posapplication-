-- Add a terminal, non-error status to notification_status_enum. General-purpose gap, not a PUSH
-- workaround: "PENDING -> SENT or FAILED" has no way to say "this was never going to send, and
-- that's not an error" — no email on file, opted out mid-flight, a channel retired, or (today)
-- PUSH having no delivery transport. Justified on its own: ADD VALUE has no DROP VALUE in Postgres
-- (same one-way door as D1's number_series_type_enum labels), so this is meant to outlive PUSH.
--
-- SEPARATE MIGRATION, required, not by choice: Postgres allows ADD VALUE inside a transaction block,
-- but the new value cannot be USED until that transaction commits, and `supabase db push` wraps each
-- migration file in its own transaction. A later migration reads/writes 'SKIPPED'.
alter type public.notification_status_enum add value if not exists 'SKIPPED';
