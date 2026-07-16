# PROJECT STATE — Lumina POS

Last updated: 2026-07-16

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
All flows end-to-end. 33+ routes, auth redirect, StatefulShellRoute bottom nav. RBAC, branch selection, PIN lock
+ biometric, TOTP MFA (clean-arch, typed AuthFailure — transient fault shows retry banner, not lockout),
device/session/security management.

## Inventory — COMPLETE (Slices A/B/C; detail in DECISIONS.md)
Catalog (categories/brands/products + variants/images/pricing, barcode templates, trigram search, SKU auto-gen,
soft-delete RPCs). Stock engine (trigger-maintained stock_balance over immutable stock_ledger; all writes via
post_stock_movement; negative blocked; warehouses CRUD + opening-balance + levels + ledger). Stock ops
(adjustments/transfers/counts, imei_records, inventory_settings, number_series; +4 enums, 10 RPCs; full clean-arch).

## Database Migrations

Ordered, applied set lives in `supabase/migrations/` (filenames = the index); each migration's rationale is
logged in DECISIONS.md by date. Coverage: auth/RBAC → catalog/stock → sales/returns → dashboard → purchasing/CRM
ledgers → M07 accounting (7 money paths post-S8) → M08 reporting → M09 repair → M11 notifications.

## Peripheral features — COMPLETE (detail in DECISIONS.md)
Barcode scanning (mobile_scanner, shared scanBarcode/BarcodeScanPage); label printing (pdf/printing/barcode,
LabelPdfService + LabelPrintPage); notifications (+prefs, trg_low_stock_notify, hub bell badge); bulk CSV import
(bulk_import_products RPC + ImportProductsPage); voice search (speech_to_text mic in products search).

## Known Issues
- Profile loaded once (no pull-to-refresh); IMEI section not yet in product edit form (SERIALIZED)
- ✓ FIXED 2026-07-16: number_series landmine (D1: Golden 10 seeded + next_number raises on any gap); cron reproducibility (D5: all 7 pg_cron jobs now in migrations/cron_bootstrap.sql, reconciled from live + diffed clean). (DECISIONS.)
- BUILD STATE (2026-07-16): macOS FIXED (osx 10.15→11.0). ANDROID FIXED — file_picker 3.0.4→12.0.0-beta.7 (only 12.x clears the win32-6
  clash) + `.platform` removed at 2 sites; `build apk` ✓; 6 withData/bytes deprecation infos kept (readAsBytes=future task). (DECISIONS.)

## Tenant Provisioning — COMPLETE (creation-time, gate-proven; detail in DECISIONS.md)
`provision_tenant()` seeds the golden set (20 CoA / 10 number_series / 4 tax / OPEN fiscal / 3+3 templates /
REPAIR-SERVICE sentinel / Main Warehouse / 7 payment methods) idempotently; `verify_tenant_provisioning()` gates
it (payment_methods expected 7, folded into `complete`). Migrations tenant_provisioning_verify/_seed/
_seed_tax_mode_cast_fix/_wire_signup + settings_payment_methods/_provision_tenant_payment_methods. handle_new_user calls it in the signup
txn (no exception swallow — failure rolls signup back atomically). All 5 tenants complete=true; new business signups
born complete with zero manual steps. P4 gate (rolled-back txn firing the real on_auth_user_created trigger, NOT a
live app signup): a provisioned tenant sells (balanced journal INV-BR01-000001), closes a repair (4200), disburses
payroll (6200), and posts a journal into its monthly period — zero manual seeding. Fault closed end-to-end; first
genuine customer signup will be the first LIVE execution of the wired path.
Ops: cron verify_provisioning_daily (jobid 10) alerts admins on any complete=false. Fiscal: reuses
current_fiscal_period (sole creator, MONTHLY, self-aligning); verify checks fiscal_period_monthly for granularity drift.

## Migration Import — COMPLETE
`lib/features/migration_import/` clean-arch (reuses InventoryFailure). 4 set-based RPCs (migrate_import_categories/
brands/products/stock); MigrationImportPage — 4 FK-ordered step cards. Route /inventory/import-migration.

## Sales V1 — Core COMPLETE

DB foundation (S1): customers, cashier_sessions, invoices, invoice_items, payments + RLS; RPCs create_sale,
open/close_cashier_session, create_sales_return, void_invoice; invoice-immutability trigger; INVOICE
number_series seed. Full clean-arch sales feature: POS terminal (search+scan, cart, customer picker,
multi-payment/credit, tax, hold/resume, void, return), DB-backed session lifecycle (open/close, variance,
staleness), cart autosave, history+detail (Reprint/Share), 80mm receipt PDF. Permission-gated routes +
bottom-nav. create_sale enforces min_selling_price + credit_limit (overridable by sales:approve).
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
- Dispatch (notifications_dispatch + notify_status_enum_cast_fix): notify() single producer — IN_APP DELIVERED + one PENDING/extra channel; render_template / mark_all_read / unread_count / upsert_preference. Producers migrate incrementally.
- Detectors (notifications_detectors): fn_overdue_receivables / fn_unpaid_salaries / fn_stock_mismatch + fn_low_stock_notify → daily-idempotent IN_APP alerts; pg_cron 07:00 (in migrations/cron_bootstrap.sql, D5). Gate-proven.
- Sender (edge fn notification-sender) + Push (notifications_device_tokens): service-role (unauth→401) drains PENDING notifications/comm_logs/report_deliveries via Twilio+SendGrid+FCM v1, marks SENT/FAILED; deployed, inert until keys; cron trigger DEFERRED. Keys: TWILIO_*/SENDGRID_KEY/FROM_EMAIL/FCM_SERVICE_ACCOUNT. Flutter firebase_messaging DEFERRED.
- UI COMPLETE (features/notifications/): NotificationBell (badge, 30s poll) → /notifications Center (filters, deep-links, mark-all-read) + /settings (6 event_types × 5 channels, PUSH chip disabled-with-reason 2026-07-16 D3 — no device can register a token). Admin: /templates, /bulk, /logs. NEXT: sender FCM branch must SKIP not FAIL unsendable PUSH rows (D3, before any key is set); provider keys + drain cron; migrate producers to notify().

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
UI (S6): `lib/features/settings/` clean-arch, ONE settings_remote_datasource, typed SettingsFailure. SettingsHubPage is the
bottom-nav /settings target (settings:read) → Profile&Security (reused auth page), Business settings (settings_json), Branches
(per-branch currency/timezone), Payment methods (update/link/toggle only — 7 enum rows are the complete set), Tax rules, Number
series (read-only; fiscal_year_reset DROPPED 2026-07-16 D2, sign-off #1), Preferences (theme/language/default branch), Notifications. formatPkr follows the
active branch currency. auth SettingsPage stays in features/auth/ (move deferred — breaks imports).

## M09 Repair & Service — COMPLETE (backend + Flutter)
Backend (applied + gate-verified; full per-phase detail in DECISIONS 2026-07-13/14): repair_jobs/parts/
status_history + repair_status_enum(9), RJ- series, REPAIR-SERVICE sentinel (type=SERVICE) + 4200 Service
Revenue, REPAIR_USE movement. Lifecycle RPCs + close_repair_job (7th money path: builds invoice + REPAIR_INVOICE journal;
parts COGS Dr 5000/Cr 1200). Pipeline C3–C6: bulk_change_repair_status + technician perf; C4 communication_logs notify
intents; C5 parts output tax; C6 WARRANTY_CLAIM re-repair (original_repair_id self-FK, 5200 Warranty Cost, revenue-free).
SERVICE non-stock guard; signature capture (private bucket + RLS, 60s signed URLs).
Flutter (`lib/features/repair/`): kanban (drag + bulk), intake, detail (diagnosis/parts/assign; close BRANCHES Close&Invoice
vs Warranty-no-charge + warranty link card), workload, history, QR label. DEFERRED: /repair/:id/edit, intake signature,
board branch filter, customer SMS/email.

## M10 HR & Payroll — COMPLETE (backend H1–H6 + UI H7.1–H7.3)
Backend (all migrations applied + rolled-back-gate-verified; full per-phase detail in DECISIONS 2026-07-14):
- H1 foundation: 7 enums, employees+shifts tables, RLS (tenant read / hr-gated writes), NEW `hr` perm module
  (+trg_seed_hr_perms), CoA seeds 6200 Salary / 2120 Deductions Payable / 1150 Employee Advances.
- H2 lifecycle: create/update(COALESCE)/terminate_employee, upsert_shift (dup code → ERR_CODE_TAKEN).
- H3 attendance+leaves: mark_attendance (late/OT vs shift, edit needs reason), apply/decide_leave (approve stamps ON_LEAVE).
- H4 payroll calc: create_payroll_run → calculate_payroll (basic + OT − advance − deductions, net≥0) → approve_payroll_run.
- H5 disburse (**8th money path**): disburse_payroll_run posts balanced PAYROLL journal (Dr 6200 / Cr 1150/2120/1000), items PAID.
- H6 salary advances (**9th money path**): disburse_salary_advance (Dr 1150 / Cr 1000), recovered via payroll.
  Both disburse RPCs forward-fixed a `post_journal() into uuid` 22P02 (jsonb→uuid) via `->>'journal_entry_id'`.

HR UI (`lib/features/hr/`, full clean-arch; per-slice detail in DECISIONS H7.1–H7.3): 7 entities/enums, sealed HrFailure(11),
ONE HrRemoteDataSource, usecases + controllers. H7.1 employees/shifts (form create-only, profile 4 tabs). H7.2 attendance/
leaves (edit-reason required, apply/approve/reject, clock in/out). H7.3 payroll (status-driven DRAFT→CALCULATED→APPROVED→
DISBURSED + View journal, PayslipPdf, Give-Advance). Routes /hr/*; hub gated hr:read. analyze clean.

## M11 Approvals — Backend (foundation+engine+escalation) + Approval Center + Workflow-config UI
Foundation `20260714093114_approvals_foundation.sql`: approval_status_enum(6) + approval_workflow_type_enum(8); tables
approval_workflows/requests/actions §3.17 + indexes (incl uq open-request-per-entity — one PENDING/ESCALATED per entity);
RLS tenant-read / RPC-only writes; NEW `approvals` perm module (6 actions backfilled to ADMIN + trg_seed_approvals_perms).
Engine `20260714093553_approvals_engine.sql` (gate-verified): upsert_approval_workflow, request_approval (resolves workflow by
threshold; no match → required:false so callers proceed; idempotent per open entity), act_on_approval (level required_role,
ADMIN super-approver, min_approvers, advances level, last→APPROVED, append-only audit), cancel_approval_request.
Escalation `20260714094049_approvals_escalation.sql`: escalate_expired_approvals (PENDING past expires_at → ESCALATED); pg_cron
hourly (approvals_escalation_hourly). UI `lib/features/approvals/` (mirror of hr/): ONE datasource, ApprovalFailure(8),
controllers + count/detail providers. Pages: PendingApprovals /approvals, Detail /approvals/:id (ladder + timeline + deep link,
Approve/Reject gated), History. Workflow-config (approvals:update): Workflows + WorkflowForm (type/threshold/TTL + levels editor
→ upsert_approval_workflow). analyze clean. A5 PO integration LIVE (po_approval_integration): submit_purchase_order raises
request_approval('PURCHASE_ORDER',po,grand_total); approve_purchase_order blocked (ERR_APPROVAL_REQUIRED) while chain
PENDING/ESCALATED/REJECTED. Inert w/o a workflow — regression-proven byte-for-byte. NEXT: wire other 7 types (deferred).
