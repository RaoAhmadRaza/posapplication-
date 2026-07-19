# PROJECT STATE — Lumina POS

Last updated: 2026-07-17

## Stack & Architecture

Flutter + Supabase (Postgres + Auth + Storage). Clean architecture with plain Riverpod
(no codegen, no build_runner) and go_router. Dependency chain:

```
page → controller (Notifier<AsyncValue<T>>) → use case (Provider) → repository (abstract)
→ repository impl → remote datasource → supabase
```

## Project Structure

```
lib/
  main.dart app.dart router.dart
  core/design/  (tokens + theme + shared widgets)
  core/services/ (pin, device, mfa, audit, login_throttle, scanner_support)
  core/widgets/  (bottom_nav_shell, pin_pad, permission_gate, barcode_scan_page)
  features/auth/ (21 pages, 12 controllers)
  features/inventory/ (catalog + stock-engine + stock-ops + barcode + labels)
  features/notifications/ (entities, model, datasource, repo, controller, page)
  features/sales/ (data + domain + controllers + 7 pages + receipt service)
    domain/entities/  7  domain/failures/  sealed SalesFailure  domain/usecases/  7
    data/models/  6  data/datasources/  1  data/repositories/  1  data/services/  1 (receipt PDF)
    presentation/controllers/  4  presentation/pages/  7 (open/close session, POS terminal, payment, success, receipt)
  features/dashboard/ (data + domain + controller)
  features/{purchasing,suppliers,customers,accounting,repair,hr}/ (full clean-arch per feature)
```

## Auth — COMPLETE
All flows end-to-end. 33+ routes, auth redirect, StatefulShellRoute bottom nav. RBAC, branch selection, PIN lock +
biometric, TOTP MFA (clean-arch, typed AuthFailure — retry banner not lockout), device/session/security management.

## Staff-onboarding (QR) — Phases 1–9 DONE, feature COMPLETE (2026-07-18; detail in DECISIONS)
Runbook v3. Phase 1 (security, ships alone): closed CRITICAL self-role-escalation — "users update own" RLS now has a
WITH CHECK pinning tenant_id/role_id to the pre-update snapshot (auth_tenant_id/auth_role_id) + column-grant limiting
authenticated UPDATE to full_name/phone/avatar_url/pin_hash. Removed anon lock/unlock DoS (Option A): revoked
increment/reset_failed_login from anon/public, deleted client sites, LoginThrottleService local-only. provision_tenant
revoked from public/anon + ERR_FORBIDDEN_TENANT guard (auth.uid()-NULL signup path exempt). hierarchy_level backfilled
(3 dirty tenants → ADMIN=1/CASHIER=5) + guard_role_hierarchy trigger. New helpers is_admin_role_name, auth_can_grant_role
(drift-proof subset gate). Verified via rolled-back probes; live cashier-JWT + app-signup smoke = owner acceptance.
Phase 2 (phase2_staff_invites_schema): invite_status_enum + staff_invites/staff_invite_branches (token_hash unique,
multi-branch, expiry) RLS read-only, no write/anon policy. Phase 3 (phase3_staff_invite_rpcs): 7 SECURITY DEFINER fns —
create (four-guard name/subset/level/branch), validate (anon pre-auth), consume (trigger-only race-safe single-use),
revoke/list/regenerate/release_abandoned. Phase 4 (phase4_handle_new_user_invite): handle_new_user now 4-path —
invite_token→join existing tenant (stub-insert+consume+backfill FK-order fix; token scrubbed), business_name→ADMIN
(unchanged), demo_mode→Demo (gated), else→raise. All 4 gate-proven through the real trigger. Phase 5
(phase5_roles_permissions): list_permission_catalog/create_tenant_role/update_role_permissions/list_tenant_roles +
update_user_role (2nd escalation door — same 4 guards + last-admin lockout). Gate-proven via rolled-back JWT-claim
impersonation as ADMIN. Phase 6 (Flutter `lib/features/staff/`, clean-arch mirror of approvals + list_tenant_users RPC):
6 pages — staff invites (list/revoke/regenerate/release), invite create, QR (shown-once token), roles+members tabs,
role form (permission picker), user role change; wired into router + Settings "Team" group + HR "Create login" (first
writer of employees.user_id). Phase 7 (invitee, first pre-auth path): login "Scan invite QR" → /join/scan (MobileScanner,
both token shapes) → validate (anon) → /join/redeem (signUp with invite_token, never business_name) → /otp → in; join
routes added to pre-auth authRoutes. Phase 8 (signup gating): business name now REQUIRED client-side + "Try demo"
button (demoMode threaded through signUp chain) — no more blank→Demo-Store→trigger-500. Phase 9 (tests): full guard
matrix runtime-proven via rolled-back impersonation (S18/S19 lateral-grant, S15 last-admin, S21 null-hier all blocked;
1.10 blocks ADMIN re-drift); data integrity clean. Remaining: owner on-device acceptance (PIN/MFA/POS smoke). analyze clean.

## Inventory — COMPLETE (Slices A/B/C; detail in DECISIONS.md)
Catalog (categories/brands/products + variants/images/pricing, barcode templates, trigram search, SKU auto-gen,
soft-delete RPCs). Stock engine (trigger-maintained stock_balance over immutable stock_ledger; all writes via
post_stock_movement; negative blocked; warehouses CRUD + opening-balance + levels + ledger). Stock ops
(adjustments/transfers/counts, imei_records, inventory_settings, number_series; +4 enums, 10 RPCs; full clean-arch).

## Database Migrations

Ordered, applied set lives in `supabase/migrations/` (filenames = the index); rationale logged in DECISIONS.md by
date. Coverage: auth/RBAC → catalog/stock → sales/returns → dashboard → purchasing/CRM ledgers → M07 accounting
(7 money paths) → M08 reporting → M09 repair → M11 notifications → security (Phase 1).

## Peripheral features — COMPLETE (detail in DECISIONS.md)
Barcode scanning (mobile_scanner, shared scanBarcode/BarcodeScanPage); label printing (LabelPdfService/LabelPrintPage);
notifications (+prefs, trg_low_stock_notify, hub bell badge); bulk CSV import (bulk_import_products); voice search (speech_to_text).

## Known Issues
- Profile loaded once (no pull-to-refresh); IMEI section not yet in product edit form (SERIALIZED)
- ✓ FIXED (DECISIONS): number_series landmine (D1); cron reproducibility (D5). BUILD: macOS+Android OK; file_picker pinned 12.0.0-beta.7 (D4), withData/bytes→readAsBytes() still pending.
- Auth test diagnosis (docs/AUTH_TEST_DIAGNOSIS.md, 2026-07-19): 11 clusters from a 59-case manual test pass
  verified against source. Confirmed real bugs, no fixes applied yet: `sessions` table never written (dead
  write path); `audit_logs` insert omits tenant_id → every row RLS-invisible; Android biometric fails silently
  (`MainActivity` needs `FlutterFragmentActivity`); no branch-create UI anywhere + branch-select unreachable for
  single-branch tenants; signup doesn't detect duplicate email (routes to OTP instead of erroring); login
  silently no-ops on empty fields (signup does show an error); password-strength meter is length-only.
  Two "screens are missing" reports (MFA, and much of Settings/security) turned out to be `settings:read`
  permission-gating the seeded CASHIER role out of those screens entirely, not missing features — and
  `update_role_permissions` (role-editing) is fully built server-side but has zero client call sites.

## Tenant Provisioning — COMPLETE (creation-time, gate-proven; full detail in DECISIONS.md)
`provision_tenant()` seeds the golden set (20 CoA / 10 number_series / 4 tax / OPEN fiscal / 3+3 templates /
REPAIR-SERVICE sentinel / Main Warehouse / 7 payment methods) idempotently; `verify_tenant_provisioning()` gates it
(`complete`). handle_new_user calls it in the signup txn (failure rolls signup back atomically). Phase 1 hardened it:
revoked from public/anon + ERR_FORBIDDEN_TENANT guard (signup path exempt via auth.uid()=NULL). Ops: cron
verify_provisioning_daily alerts admins on any complete=false; fiscal reuses current_fiscal_period (MONTHLY).

## Migration Import — COMPLETE
`lib/features/migration_import/` clean-arch (reuses InventoryFailure). 4 set-based RPCs (migrate_import_categories/brands/products/stock); MigrationImportPage 4 FK-ordered step cards. Route /inventory/import-migration.

## Sales V1 — Core COMPLETE

DB foundation (S1): customers, cashier_sessions, invoices, invoice_items, payments + RLS; RPCs create_sale,
open/close_cashier_session, create_sales_return, void_invoice; invoice-immutability trigger; INVOICE
number_series seed. Full clean-arch sales feature: POS terminal (search+scan, cart, customer picker,
multi-payment/credit, tax, hold/resume, void, return), DB-backed session lifecycle (open/close, variance,
staleness), cart autosave, history+detail (Reprint/Share), 80mm receipt PDF. Permission-gated routes +
bottom-nav. create_sale enforces min_selling_price + credit_limit (overridable by sales:approve); tax is
server-authoritative (D6, 2026-07-16 — from tax_rules, client tax_pct ignored, raises if no active rule).
close_cashier_session gated sales:create + owner-only. Live-sales banner via sessionSalesProvider (no silent
zero). Full per-slice detail in DECISIONS.md.

### Sales V1 Deferred
delivery_orders, loyalty, customer_groups, pricing-tier. (offline sync → Sync/Offline §3.3.)

## Dashboard V2 — COMPLETE (relocated to features/dashboard/, clean-arch)
page moved out of auth/ → features/dashboard/presentation/pages/. reports:read gate, pull-refresh, fl_chart bar+pie,
recent sales, quick-launch. 10-KPI grid (6 orig + payables/cash/bank/pl) CONFIGURABLE — show/hide + order persisted
SERVER-SIDE per user via ui_preferences.dashboard_layout_json / upsert_ui_preferences (clean-arch, read on load / write
on change; first run migrates any legacy shared_preferences layout up once, then server-authoritative). Each KPI taps a DrilldownPage
over drilldown_* RPCs; rows deep-link (invoice→/sales/invoice, product→/inventory/stock, journal→/accounting/journal).

## M08 Reporting — backend LIVE (DB layer), all gate-proven rolled-back
- MVs (reporting_materialized_views): 6 matviews (daily_sales [fan-out FIXED], inventory_valuation [canonical], account_balances, cust/supp_aging, product_performance) refreshed CONCURRENTLY; raw select revoked (definer RPCs).
- Drilldowns (reporting_drilldowns/_complete/_payables): 6 RPCs leak-proven; ALL 10 dashboard KPIs tappable (stock_value+pl→existing pages).
- Scheduling (reporting_schedules + deliveries_fix): run_due (pg_cron */15) queues PENDING report_deliveries; SEND = M11 dep.
- Analytics (analytics_events): immutable partitioned+gin, RLS read-own/definer-write (FLAG: only a DEFAULT partition, no time-bounded ones — inserts degrade not reject). AI recs (ai_recommendations): generate_reorder_recommendations + act_on_recommendation; ML deferred.
- Reporting UI COMPLETE (features/reporting/ + reporting_read_rpcs): ReportsHubPage /reports + Inventory/Product-Perf/Cust-Supp-Aging/Trends/Forecasting (fl_chart, definer RPCs over MVs), ScheduledReports (reports:export), SmartInsights (ai_recs + REORDER→Create-PO), PDF/CSV export.

## M11 Notifications — ACCEPTED (all layers LIVE; provider keys pending)
- Templates (notifications_templates): sms+email (§3.13) seeded 3+3/tenant, {{placeholder}}. NEW 'notifications' perm module (6 grants/ADMIN × 5 tenants). RLS tenant-read + notifications:update. Gate-proven.
- Dispatch (notifications_dispatch + notify_status_enum_cast_fix + notify_skip_push_no_transport D3 2026-07-17): notify() single producer — IN_APP DELIVERED + one PENDING/extra channel, PUSH skipped entirely (no transport); render_template / mark_all_read / unread_count / upsert_preference. Producers migrate incrementally. NOTE: notification_preferences is empty (0 rows) — notify() has never executed in production.
- Detectors (notifications_detectors): fn_overdue_receivables / fn_unpaid_salaries / fn_stock_mismatch + fn_low_stock_notify → daily-idempotent IN_APP alerts; pg_cron 07:00 (in migrations/cron_bootstrap.sql, D5). Gate-proven.
- Sender (edge fn notification-sender) + Push (notifications_device_tokens): service-role (unauth→401) drains PENDING notifications/comm_logs/report_deliveries via Twilio+SendGrid+FCM v1, marks SENT/FAILED/SKIPPED (PUSH-no-token -> SKIPPED, D3 2026-07-17, one-shot sender has no retry so FAILED there was unrecoverable); deployed, inert until keys; cron trigger DEFERRED. Keys: TWILIO_*/SENDGRID_KEY/FROM_EMAIL/FCM_SERVICE_ACCOUNT. Flutter firebase_messaging DEFERRED. FLAGGED not built: sender is one-shot, no attempts/retry column — a real transient error (e.g. SendGrid down) permanently kills a notification today, PUSH or not.
- UI COMPLETE (features/notifications/): NotificationBell (badge, 30s poll) → /notifications Center (filters, deep-links, mark-all-read) + /settings (6 event_types × 5 channels, PUSH chip disabled-with-reason 2026-07-16 D3). Admin: /templates, /bulk, /logs. NEXT: provider keys + drain cron; migrate producers to notify(); sender retry design (flagged above).

## Purchasing — COMPLETE (back end + Flutter)

Back end (migrations, all applied): suppliers, purchase_orders(+items), grns(+items), purchase_invoices,
supplier_payments; RPCs create/update/submit/approve/cancel_purchase_order, receive_goods,
create_purchase_invoice, record_supplier_payment (overpayment guard), supplier_ledger, payables_aging.
Landed cost by line_total; canonical warehouse_id NULL stock via post_stock_movement PURCHASE_RECEIPT; serialized IMEI →
imei_records AVAILABLE. PO lifecycle DRAFT→SUBMITTED→APPROVED→PARTIALLY_RECEIVED/RECEIVED→INVOICED, CANCELLED. Two
receive_goods bugs forward-fixed: enum-cast (20260711101802), imei IN_STOCK→AVAILABLE (20260711111535).

## Sync / Offline (§3.3) — D1–D11 LIVE — SYNC & OFFLINE COMPLETE (gate-proven)
D11 sync_retry_intent (20260716161000, LIVE — not money): closed the exception GRAVEYARD (resolve only ANNOTATED; the lost sale
never posted). retry_sync_intent (sync:resolve) re-queues an ABANDONED/FAILED intent + replays inline impersonating the original
cashier; D4 key ⇒ exactly one invoice, already-applied = no-op. sync_replay guard OPEN-scoped so a re-failed retry re-surfaces.
Flutter Retry action beside Resolve. Gate green: graveyard→recover→no-double-post→re-surface.
D10 sync_replay_classifier_fix (20260716160000, LIVE — not money): closed bug class #7 (silent FAILED-at-cap). terminal regex +=
NO_TENANT|PERMISSION_DENIED (revoked/tenant-less cashier → ABANDONED+exception; was stuck FAILED<cap invisible); transient at cap
(attempts+1≥5) now also surfaces. Gate before/after: 3 silent holes → visible; below-cap transient still retries (no over-fire).
SIGN-OFF #5 (p_transaction_date) DEFERRED BY CHOICE — accepted latent misstatement, NOT "safe": posting at current_date IS the
defect, open period only makes it SILENT (sale synced across midnight/month-end books to the wrong day/period, all gates green).
REVISIT at month-end or on any overnight-offline report. See DECISIONS Sign-off #5.
D1 sync_pull_reference (20260716073759 + fix 125000, LIVE): Class A pull-only delta + stock_balance full pull; SECURITY DEFINER
per-subquery tenant filter evicts soft-delete tombstones (INVOKER RLS silently dropped them). D2 sync_foundation (075906):
sync_outbox + sync_exceptions (append-only, NEVER makes an invoice) + 2 enums + `sync` perm; RPC-only writes (insert→42501).
D3 sync_invoice_idempotency (131500): invoices += idempotency_key/device_id/local_ref; uq_invoices_idem PARTIAL = un-raceable
double-post guard. D4 sync_create_sale_idempotency (133000, MONEY): create_sale += p_idempotency_key (drop+create 7-arg); replay
returns the ORIGINAL invoice, guard BEFORE next_number, ACL re-hardened. (full per-D detail in DECISIONS)
D7.1 CLIENT (lib/features/sync/, mirrors approvals; +sqflite/ffi/connectivity_plus/uuid, NO build_runner): sqflite cache (hand
DAOs) + pull-reference watermark delta (deleted_at→evict); ConnectivityMonitor. Offline CASH-ONLY — a cash sale appends a SALE
intent (uuid key, provisional local_ref), NEVER create_sale. POS: SyncStatusWidget; credit/returns/customer/close-register
disabled offline w/ reason; search cache-first; success shows local_ref PROVISIONAL.
D7.2 replay drain + Exception Centre (sync_push_intent 20260716151500 — idempotent client→server enqueue): on reconnect DRAIN
oldest-first ONE AT A TIME; idempotent 3 ways (push key + replay guard + create_sale key) → drain-twice/kill-mid = 3 invoices not 6.
SyncExceptionCentrePage /sync/exceptions (sync:read, product deep-links, Resolve/Retry). SyncStatusSheet. sqflite v2 (onUpgrade).
D8 ops (sync_drain_cron 20260716154500): cron `sync_outbox_drain_5min` (*/5, in migrations/cron_bootstrap.sql) drains server-side — impersonates each row's
cashier (pg_cron has no JWT) then routes through sync_replay_sale_intent; service_role only; registered AFTER D4/D5 green.
DEFERRED (full list in DECISIONS): sync_log/conflicts/domain_events (superseded LWW); offline variants/stock caching; #5; probe.
D5 sync_replay_driver (20260716134500, LIVE): sync_replay_sale_intent (for-update-skip-locked → create_sale w/ the outbox key →
APPLIED + stamps is_offline/synced_at/device_id/local_ref) + resolve_sync_exception. Terminal→ABANDONED + sync_exceptions;
transient→FAILED. RELAXED fn_invoice_immutability for a metadata-only stamp on a PAID invoice (jsonb-diff, financials still
immutable — gate-proven). Classifier holes later closed in D10.

### Purchasing (Flutter) — COMPLETE
`lib/features/purchasing/` full clean-arch (mirrors suppliers/sales): 6 entities + 2 status enums + 5 RPC result types;
sealed PurchaseFailure; 13 usecases; ONE PurchaseRemoteDataSource (all selects + 8 RPCs) → typed failures. Controllers:
PurchaseOrders (list/status/create/edit/submit/approve/cancel/receive) + detail/grns providers; PurchaseInvoices
(create→match_variance) + payments; PurchasePayments. 10 pages: Hub, PO list, PO form (supplier + inline product-search
editor + charges + live totals, edit DRAFT-only, accepts reorder seed), PO detail (status-gated actions + linked GRNs/
invoices), GrnReceive (per-line qty/reject/batch/expiry + IMEI for SERIALIZED), InvoiceMatch (3-way variance), invoices
list+detail (Record Payment), SupplierPayment (blocks overpayment), ReorderSuggestions (≤reorder_point → seeds PO).
Routes /purchasing/* + 5th "Purchase" bottom-nav branch gated purchase:read. DB lifecycle verified rolled-back. analyze clean.

### Suppliers CRM (Flutter) — COMPLETE
`lib/features/suppliers/` full clean-arch: Supplier/SupplierStatus + SupplierLedger/PayablesAging entities; sealed
SupplierFailure; 7 usecases; SuppliersRemoteDataSource (ILIKE search, status filter, ledger/aging RPCs); controller +
ledger/aging providers. Pages: list (search, status chips, payable hint, FAB purchase:create), form (purchase:update/
delete), detail (ledger balance/timeline + Record Payment TODO). Routes /suppliers[/create|/:id|/:id/edit]; hub row. Verified vs live RLS.

### Customers CRM (Flutter) — COMPLETE (parity with suppliers)
`lib/features/customers/` full clean-arch mirroring suppliers (Customer moved from sales — old paths re-export).
CustomerLedger/ReceivablesAging entities; CustomerFailure; usecases + datasource (customer_ledger/receivables_aging) +
controllers. Pages: list, form, detail (credit + ledger + Collect Payment), ReceivablesAging. Collect-payment:
record_customer_payment + unpaid-invoice picker → CustomerPaymentPage (/customers/:id/collect, sales:create, overpayment
blocked). Receivables KPI; POS chip shows remaining credit; CreditLimitExceededFailure from create_sale. DEFERRED: groups,
loyalty, comms, bulk import, statements.

### Purchase Returns (Flutter) — COMPLETE
`lib/features/purchasing/` extended. Debit-note-style return of received goods. Domain: PurchaseReturn(+Item/Status/
ReturnCreateResult); PurchaseFailure += ReturnExceedsReceived/ImeiCountMismatch/ImeiNotFound. 4 usecases; datasource
(loadPurchaseReturns/loadReturnedQtysForPo embedded-summed / rpc create_purchase_return p_reduce_invoice=false) +
controller/providers. Pages: list (+status), detail (lines + returned IMEIs), form (mirrors GRN receive: received/
already-returned/available per line, qty bounded, SERIALIZED needs exactly qty IMEIs, reason required). Entry: PO detail
"Return" + invoice "Return Against Bill" (purchase:update); routes /purchasing/returns[/create|/:id]. Ledger kind=RETURN =
credit. No migration (RPC + PR- series pre-live). Rolled-back dry-run verified incl. over-return guard.

### M07 Accounting — COMPLETE (all 6 money paths auto-post)

DB-level double-entry GL. `post_journal` = sole ledger writer (balance + immutability + CLOSED-period guard enforced;
ungated auto-posts pass `p_gate=false`). D6 (20260716140000): raises ERR_PERIOD_CLOSED into a CLOSED fiscal period —
UNCONDITIONAL (not behind p_gate; a closed period is an accounting control, not a permission). fiscal_periods.status was
decorative before (D11.4: no check existed); prerequisite for back-dating offline sales [SIGN-OFF #5]. All 6 money paths —
SALE, CUSTOMER_PAYMENT, PURCHASE_INVOICE, SUPPLIER_PAYMENT,
PURCHASE_RETURN, SALES_RETURN — emit a balanced journal (six-path gate green; trial_balance + balance_sheet true); GL
reconciles 1:1 with AR/AP subledgers. Payment→GL split CLOSED (S1–S2, S8): all 4 divergent hardcodes gone;
resolve_payment_account SOLE resolver in 7 money paths; close_repair_job keeps literal 1000 (cash-only by construction —
Deferral A). tax_rules CONSUMED (S4): resolve_tax_rate defaults product/POS tax (create_sale untouched, caller p_tax_pct
authoritative). A6 UI: `lib/features/accounting/` clean-arch — hub, CoA tree, ledger, journal list+detail (reverse gated),
manual voucher, expenses, bank/tax-rule CRUD, Reports (export gated), fiscal periods + bank reconciliation.

## Settings / M12 — S1–S8 COMPLETE (backend gated settings:update; per-phase detail in DECISIONS)
UI (S6): `lib/features/settings/` clean-arch, ONE datasource, typed SettingsFailure. SettingsHubPage = bottom-nav
/settings (settings:read) → Profile&Security, Business settings, Branches, Payment methods (7 enum complete), Tax rules,
Number series (read-only; fiscal_year_reset DROPPED D2), Preferences, Notifications. formatPkr follows branch currency.

## M09 Repair & Service — COMPLETE (backend + Flutter)
Backend (applied + gate-verified; full detail in DECISIONS 2026-07-13/14): repair_jobs/parts/status_history +
repair_status_enum(9), RJ- series, REPAIR-SERVICE sentinel (type=SERVICE) + 4200 Service Revenue, REPAIR_USE movement.
Lifecycle RPCs + close_repair_job (7th money path: invoice + REPAIR_INVOICE journal; parts COGS Dr 5000/Cr 1200).
Pipeline C3–C6: bulk_change_repair_status + technician perf; C4 communication_logs notify intents; C5 parts output tax;
C6 WARRANTY_CLAIM re-repair (original_repair_id self-FK, 5200 Warranty Cost). SERVICE non-stock guard; signature capture
(private bucket + RLS, 60s signed URLs). Flutter (`lib/features/repair/`): kanban (drag+bulk), intake, detail (close
Close&Invoice vs Warranty-no-charge + warranty link), workload, history, QR label. DEFERRED: edit, intake signature, SMS.

## M10 HR & Payroll — COMPLETE (backend H1–H6 + UI H7.1–H7.3)
Backend (all migrations applied + rolled-back-gate-verified; full per-phase detail in DECISIONS 2026-07-14):
- H1 foundation: 7 enums, employees+shifts tables, RLS (tenant read / hr-gated writes), NEW `hr` perm module
  (+trg_seed_hr_perms), CoA seeds 6200 Salary / 2120 Deductions Payable / 1150 Employee Advances.
- H2-H4: create/update/terminate_employee, upsert_shift; mark_attendance (late/OT, edit needs reason), apply/decide_leave;
  create_payroll_run → calculate_payroll (basic+OT−advance−deductions, net≥0) → approve_payroll_run.
- H5 disburse (**8th money path**): disburse_payroll_run posts balanced PAYROLL journal (Dr 6200 / Cr 1150/2120/1000).
- H6 advances (**9th money path**): disburse_salary_advance (Dr 1150 / Cr 1000), recovered via payroll.

HR UI (`lib/features/hr/`, full clean-arch; per-slice detail in DECISIONS H7.1–H7.3): sealed HrFailure(11), ONE datasource.
H7.1 employees/shifts (profile 4 tabs). H7.2 attendance/leaves (edit-reason, clock in/out). H7.3 payroll (DRAFT→CALCULATED
→APPROVED→DISBURSED + journal, PayslipPdf, advances). Routes /hr/*; hub gated hr:read.

## M11 Approvals — Backend + Approval Center + Workflow-config UI (full detail in DECISIONS)
approval_status_enum(6)+approval_workflow_type_enum(8); workflows/requests/actions + uq open-request-per-entity; RLS
tenant-read/RPC-only; `approvals` perm module. Engine (gate-verified): upsert_approval_workflow, request_approval
(workflow-by-threshold, no match→required:false, idempotent), act_on_approval (level role, ADMIN super-approver,
min_approvers, append-only), cancel; escalate_expired_approvals + pg_cron hourly. UI: PendingApprovals/Detail/History
+ Workflow-config. A5 PO integration LIVE: submit_purchase_order raises approval, approve blocked while chain open, inert w/o workflow. NEXT: wire other 7 types.
