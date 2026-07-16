-- D2: fiscal_year_reset disposition (sign-off #1, FBR: does not require year-reset numbering).
-- D0.8 proved (empty set): no function anywhere reads this column. It is the third instance of the
-- pattern after tax_rules (seeded, full CRUD UI, read by no RPC) and fiscal_periods.status (pre-guard).
-- A column with a default, a UI, and no reader. Honest disposition: the feature was never built, and
-- nothing needs it — drop it rather than build a year-component numbering module (year in every
-- format, a reset job, collision with the sync numbering deferral) to honour a flag nobody asked for.
-- No RPC touched: provision_tenant never named this column explicitly (relied on the table default),
-- so it needs no change now that the column is gone.
alter table public.number_series drop column if exists fiscal_year_reset;
