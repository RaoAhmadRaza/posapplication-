# PROJECT STATE — Lumina POS

Last updated: 2026-07-14

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

## Auth — Complete

All flows end-to-end. 33+ routes, auth redirect, StatefulShellRoute bottom nav.
RBAC, branch selection, PIN lock + biometric, TOTP MFA, device/session/security management.
MFA is clean-arch (audit D.1): MfaRemoteDataSource + MfaRepository + usecases; verify returns typed
AuthFailure? — transient network fault shows a connection/retry banner, only a real rejection shows
"Incorrect code" (no more permanent MFA lockout on flaky connections). MfaService deleted.

## Inventory — Product Catalog (Slice A) — COMPLETE

Categories, brands, products (variants/images/pricing), barcode templates.
Trigram ILIKE search. SKU auto-gen. Soft-delete via SECURITY DEFINER RPCs.

## Stock Engine (Slice B) — COMPLETE

Migration `20260613061924_stock_engine.sql`. Trigger-maintained stock_balance projection
of immutable stock_ledger. All writes via post_stock_movement RPC. Negative blocked.
Warehouses CRUD + opening-balance form + stock levels list + product detail + ledger.

## Stock Ops (Slice C) — COMPLETE

Migration `20260613075616_stock_ops.sql`: adjustments, transfers, counts, imei_records, inventory_settings,
number_series (+4 enums, 10 RPCs, all posting through the Slice B ledger). Flutter: full clean-arch
(6 entities, 16 usecases, 4 controllers, 8 pages, +13 routes) — detail in DECISIONS.

## Database Migrations

Ordered, applied set lives in `supabase/migrations/` (filenames = the index); each migration's rationale is
logged in DECISIONS.md by date. Coverage: auth/RBAC · catalog + stock engine/ops · sales + returns · dashboard ·
purchasing + supplier ledger · cust/supp CRM + ledgers · M07 accounting (6 auto-post money paths) · M08 reporting
(MVs/drilldowns/scheduling/analytics/AI recs) · M09 repair · M11 notification templates.

## Peripheral features — COMPLETE (detail in DECISIONS.md)
Barcode scanning (mobile_scanner, shared scanBarcode/BarcodeScanPage); label printing (pdf/printing/barcode,
LabelPdfService + LabelPrintPage); notifications (+prefs, trg_low_stock_notify, hub bell badge); bulk CSV import
(bulk_import_products RPC + ImportProductsPage); voice search (speech_to_text mic in products search).

## Known Issues
- Profile loaded once (no pull-to-refresh); IMEI section not yet in product edit form (SERIALIZED)

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
delivery_orders, loyalty, tax_rules/payment_methods tables, customer_groups, pricing-tier, offline sync.

## Dashboard V2 — COMPLETE (relocated to features/dashboard/, clean-arch)
page moved out of auth/ → features/dashboard/presentation/pages/. reports:read gate, pull-refresh, fl_chart bar+pie,
recent sales, quick-launch. 10-KPI grid (6 orig + payables/cash/bank/pl) CONFIGURABLE — show/hide + order per-device
in shared_preferences (edit-layout toggle; server prefs deferred, DECISION#2 client-side). Each KPI taps a DrilldownPage
over drilldown_* RPCs; rows deep-link (invoice→/sales/invoice, product→/inventory/stock, journal→/accounting/journal).

## M08 Reporting — backend LIVE (DB layer), all gate-proven rolled-back
- MVs (reporting_materialized_views): 6 matviews (daily_sales [fan-out FIXED], inventory_valuation [canonical], account_balances, cust/supp_aging, product_performance) refreshed CONCURRENTLY; raw select revoked (definer RPCs).
- Drilldowns (reporting_drilldowns/_complete/_payables): 6 RPCs leak-proven; ALL 10 dashboard KPIs tappable (stock_value+pl→existing pages).
- Scheduling (reporting_schedules + deliveries_fix): run_due (pg_cron */15) queues PENDING report_deliveries; SEND = M11 dep.
- Analytics (analytics_events): immutable partitioned+gin, RLS read-own/definer-write (FLAG: no partition helper). AI recs (ai_recommendations): generate_reorder_recommendations (idempotent) + act_on_recommendation; ML deferred.
- Reporting UI COMPLETE (features/reporting/ + reporting_read_rpcs): ReportsHubPage /reports (Financial→existing accounting reports) + Inventory/Product-Perf/Cust-Supp-Aging/Trends/Forecasting (fl_chart, definer RPCs over MVs), ScheduledReports (upsert, reports:export), SmartInsights (ai_recs accept/dismiss + REORDER→Create-PO), PDF/CSV export.
- Ops (pg_cron, MANUAL — not in migrations): mv_refresh_15min + report_schedules_runner (*/15) + reorder_daily (06:00) + approvals_escalation_hourly, all active.

## M11 Notifications — templates+dispatch+detectors+sender+push-store+UI LIVE (keys pending)
- Templates (notifications_templates): sms_templates + email_templates (§3.13) seeded 3+3/tenant, {{placeholder}} convention. NEW 'notifications' perm module (6 grants/ADMIN × 5 tenants). RLS tenant read + notifications:update write. Gate-proven.
- Dispatch (notifications_dispatch + notify_status_enum_cast_fix): notify() single producer entry — default IN_APP DELIVERED + one PENDING row/extra enabled channel for the sender; render_template({{var}}) / mark_all_notifications_read / unread_notification_count / upsert_notification_preference. Gate-proven rolled-back. Producers migrate to notify() incrementally.
- Detectors (notifications_detectors + fn_overdue_receivables_date_fix): fn_overdue_receivables / fn_unpaid_salaries / fn_stock_mismatch → daily-idempotent IN_APP HIGH/URGENT admin alerts; pg_cron 07:00 (notif_detectors_daily, MANUAL). Joins fn_low_stock_notify. Gate-proven rolled-back.
- Sender (edge fn notification-sender, N4+N5) + Push (notifications_device_tokens, SCHEMA EXT): service-role withSupabase auth:["secret"] (unauth→401) drains PENDING notifications(SMS/EMAIL/WHATSAPP + PUSH→device_tokens)+communication_logs+report_deliveries via Twilio+SendGrid+FCM v1, marks SENT/FAILED; deployed, inert until keys; TRIGGER DEFERRED (pg_net */2 cron would FAIL rows pre-keys). device_tokens + register_device_token gate-proven. Keys: supabase secrets set TWILIO_*/SENDGRID_KEY/FROM_EMAIL/FCM_SERVICE_ACCOUNT. FLUTTER firebase_messaging DEFERRED (needs Firebase project + config).
- UI (features/notifications/, extended): NotificationBell (badge, 30s poll) on Dashboard+Inventory app bars → /notifications Center (priority+unread filters, pull-refresh, deep-links repair/customer/product/payroll, mark-all-read) + /notifications/settings (6 event_types × 5 channel toggles → upsert_notification_preference). NEXT: set provider keys + activate drain cron; migrate producers to notify(); Firebase-provision for push.

## Purchasing — COMPLETE (back end + Flutter)

Back end (migrations, all applied): suppliers, purchase_orders(+items), grns(+items), purchase_invoices,
supplier_payments; RPCs create/update/submit/approve/cancel_purchase_order, receive_goods,
create_purchase_invoice, record_supplier_payment (overpayment guard), supplier_ledger, payables_aging.
Landed cost allocated by line_total; canonical warehouse_id NULL stock via post_stock_movement
PURCHASE_RECEIPT; serialized IMEI capture → imei_records AVAILABLE. PO lifecycle
DRAFT→SUBMITTED→APPROVED→PARTIALLY_RECEIVED/RECEIVED→INVOICED, CANCELLED. Two receive_goods bugs found
+ forward-fixed: enum-cast (20260711101802) and imei status IN_STOCK→AVAILABLE (20260711111535).
NOTE: number_series.include_branch_code defaults true → numbers render PO-BR01-000001 / GRN-BR01-000001 /
PV-BR01-000001 (drop branch code = one-line number_series change if desired).

### Purchasing (Flutter) — COMPLETE
`lib/features/purchasing/` full clean-arch (mirrors suppliers/sales). 6 entities + 2 status enums + 5 RPC
result types; sealed PurchaseFailure (perm/badTransition/overReceipt/overpayment/grnMismatch/notFound/
unknown); 13 usecases; ONE PurchaseRemoteDataSource (all selects + 8 RPCs); repo impl → typed failures.
Controllers: PurchaseOrdersController (list+status+create/edit/submit/approve/cancel/receive) +
purchaseOrderDetailProvider {po,items} + poGrnsProvider; PurchaseInvoicesController (create→match_variance)
+ invoicePaymentsProvider; PurchasePaymentsController. 10 pages: PurchaseHubPage, PO list, PO form
(supplier picker + inline product-search multi-line editor + charges + live totals; edit DRAFT-only;
accepts reorder seed), PO detail (status-gated Submit/Approve/Cancel/Receive/Create-Invoice + linked
GRNs/invoices), GrnReceivePage (per-line qty/reject/batch/expiry + IMEI capture for type==SERIALIZED, no
warehouse picker), PurchaseInvoiceMatchPage (3-way match variance), invoices list + detail (payments +
Record Payment), SupplierPaymentPage (payment_method_enum, blocks overpayment), ReorderSuggestionsPage
(at/under reorder_point → seeds a new PO). Routes /purchasing/* + a 5th "Purchase" bottom-nav branch
gated purchase:read. DB lifecycle verified end-to-end (impersonated ADMIN, rolled back). flutter analyze clean.

### Suppliers CRM (Flutter) — COMPLETE
`lib/features/suppliers/` full clean-arch (own folder mirroring sales/customers). Supplier +
SupplierStatus; SupplierLedger + PayablesAging entities (from the 2 read RPCs); sealed SupplierFailure;
7 usecases; SuppliersRemoteDataSource (all supabase: ILIKE name/phone, status filter, deleted_at null,
supplier_ledger/payables_aging RPCs); SuppliersController (list+search+status filter+create/edit/remove)
+ ledger/aging FutureProviders. Pages: SuppliersPage (search, status chips, payable hint, FAB gated
purchase:create), SupplierFormPage (grouped fields, gated purchase:update/delete), SupplierDetailPage
(header + ledger balance/timeline + Record Payment TODO). Routes /suppliers[/create|/:id|/:id/edit];
row on Inventory hub Purchasing section. DB pre-migrated. Verified vs live RLS.

### Customers CRM (Flutter) — COMPLETE (parity with suppliers)
`lib/features/customers/` full clean-arch mirroring suppliers (Customer moved here from sales — old paths
re-export). CustomerLedger/ReceivablesAging entities; sealed CustomerFailure; usecases + CustomersRemoteDataSource
(ILIKE search, RPCs customer_ledger/receivables_aging) + controllers. Pages: list (search/status), form (all cols),
detail (credit summary + ledger + Collect Payment), ReceivablesAging. **Collect-payment slice:**
record_customer_payment RPC + unpaid-invoice picker → CustomerPaymentPage (/customers/:id/collect, gated
sales:create, overpayment blocked). Routes + Inventory-hub Customers section + dashboard Receivables KPI; POS chip
shows remaining credit; CreditLimitExceededFailure from create_sale. DEFERRED: groups, loyalty, comms, bulk
import, statements. analyze clean.

### Purchase Returns (Flutter) — COMPLETE
`lib/features/purchasing/` extended (no new folder). Debit-note-style return of received goods to a supplier.
Domain: PurchaseReturn + PurchaseReturnItem + PurchaseReturnStatus + ReturnCreateResult; PurchaseFailure
gained ReturnExceedsReceived/ImeiCountMismatch/ImeiNotFound (invoice-mismatch reuses GrnMismatch). 4 usecases;
datasource loadPurchaseReturns / loadPurchaseReturn(+items) / loadReturnedQtysForPo (embedded
`purchase_returns!inner` filter, summed client-side) / rpc create_purchase_return (p_reduce_invoice=false).
PurchaseReturnsController + detail/poReturnedQtys providers. Pages: list (+status filter), detail (lines +
returned IMEIs), form (mirrors GRN receive: per received line shows received/already-returned/available, qty
bounded, SERIALIZED lines need exactly qty IMEIs via type/scan, reason required, live total). Entry: PO detail
"Return" (any qty_received>0) + invoice "Return Against Bill", gated purchase:update; hub row; routes
/purchasing/returns[/create|/:id]. Supplier ledger renders kind=RETURN as a credit. No migration (RPC + tables
+ PR- series pre-live). Rolled-back dry-run verified full chain incl. over-return guard. flutter analyze clean.

### M07 Accounting — COMPLETE (all 6 money paths auto-post)

DB-level double-entry GL. `post_journal` = sole ledger writer (balance/period/immutability enforced; ungated
auto-posts pass `p_gate=false`). CoA/fiscal/vouchers/expenses/reports live. All five money RPCs emit a balanced
journal, verified via rolled-back dry-runs incl. a five-path gate (every entry balanced, trial_balance +
balance_sheet true). Canonical `reference_type`: SALE, CUSTOMER_PAYMENT, PURCHASE_INVOICE, SUPPLIER_PAYMENT,
PURCHASE_RETURN (postings + cost-basis rule in DECISIONS; GRN posts no GL).
GL reconciles 1:1 with AR/AP subledgers. Ceilings: sale payments → Cash 1000 (bank split deferred); sales-return
GL not yet hooked. **A6 UI shipped:** `lib/features/accounting/` full clean-arch — hub, CoA tree, account ledger,
journal list+detail (reverse gated accounting:approve), balance-enforced manual voucher, expenses+categories,
bank/tax-rule CRUD. Reports (A6.2): filterable TrialBalance/ProfitLoss/BalanceSheet/CashBankBook (as-of/range +
branch, export gated accounting:export). Customer collect-payment on CustomerDetailPage (gated sales:create).
**Period control + bank recon (A6.3):** FiscalPeriodsPage (close/reopen gated accounting:approve) +
BankReconciliationPage (per-bank statement-vs-books snapshot, create→difference→complete). Fixed a
close-bypass: current_fiscal_period auto-minted a fresh OPEN period after close, defeating the guard — now
resolves the covering period regardless of status (trg_journal_check_period is the sole enforcer), creating
only on a genuine gap. Verified: close→journal rejected, reopen→posts, gap-month→auto-creates.
**LEDGER COMPLETE:** create_sales_return now auto-posts SALES_RETURN (tax-free: Dr 4100 / Cr 1000 refund /
Cr 1100 AR; goods back at COST BASIS Dr 1200 / Cr 5000). All 6 money paths — SALE, CUSTOMER_PAYMENT,
PURCHASE_INVOICE, SUPPLIER_PAYMENT, PURCHASE_RETURN, SALES_RETURN — post a balanced journal; verified by a
six-path rolled-back gate (all balanced, trial_balance + balance_sheet true). Journal immutable/balanced/
period-guarded. Deferrals: sales returns refund tax-free (no Output-Tax reversal); non-cash payments still
debit 1000 Cash not 1010 Bank (payment-method→account split pending — Bank Book/Recon run near-empty).

## M09 Repair & Service — COMPLETE (backend + Flutter)
Backend (applied + gate-verified; full per-phase detail in DECISIONS 2026-07-13/14): repair_jobs/parts/
status_history + repair_status_enum(9), RJ- series, REPAIR-SERVICE sentinel (type=SERVICE) + 4200 Service
Revenue, REPAIR_USE movement. Lifecycle RPCs + close_repair_job (**7th money path**: builds invoice directly +
REPAIR_INVOICE journal; parts COGS Dr 5000/Cr 1200 at captured cost). Pipeline C3–C6: bulk_change_repair_status
+ technician perf; C4 communication_logs notify intents (PENDING until M11 sender); C5 parts output tax;
C6 WARRANTY_CLAIM re-repair (original_repair_id self-FK, 5200 Warranty Cost, cost-only revenue-free close).
SERVICE non-stock guard at post_stock_movement. Signature capture (private bucket + RLS, SignaturePad, 60s
signed URLs).
Flutter (`lib/features/repair/`, full clean-arch): kanban (drag + multi-select bulk), intake, detail (diagnosis/
parts/assign; close BRANCHES Close&Invoice vs Warranty-no-charge; warranty link card + live breakdown), workload
(perf metrics), history (search), QR device label. analyze clean; data-path gate-verified, device tap-through
user-driven. DEFERRED: /repair/:id/edit (no RPC), intake signature, board branch filter, customer SMS/email.

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

HR UI (`lib/features/hr/`, full clean-arch; per-slice detail in DECISIONS H7.1–H7.3): 7 entities + 7 enums,
sealed HrFailure(11), ONE HrRemoteDataSource (all selects + RPCs), repo→typed failures, usecases + controllers.
H7.1 employees/shifts: EmployeesPage, EmployeeFormPage (create-only code/branch/joining/cnic), EmployeeProfilePage
(4 tabs), ShiftsPage. H7.2 attendance/leaves: AttendanceGridPage (NOTES-required-on-edit → ERR_EDIT_REASON_REQUIRED),
LeavesPage (apply/approve/reject), ClockInOutPage; Profile tabs. H7.3 payroll: PayrollRunsPage + PayrollRunDetail
(status-driven single action DRAFT→CALCULATED→APPROVED→DISBURSED, "View journal"), PayslipPdfService, Give-Advance.
Routes /hr/*; Inventory-hub "HR & Payroll" gated hr:read. analyze clean.
Pre-existing gap: handle_new_user seeds no CoA → future tenants lack HR accounts until provisioning is fixed.

## M11 Approvals — Backend (foundation+engine+escalation) + Approval Center + Workflow-config UI
Foundation `20260714093114_approvals_foundation.sql`: approval_status_enum(6) + approval_workflow_type_enum(8); tables
approval_workflows/requests/actions §3.17 + indexes (incl uq open-request-per-entity — one PENDING/ESCALATED per entity);
RLS tenant-read / RPC-only writes; NEW `approvals` perm module (6 actions backfilled to ADMIN + trg_seed_approvals_perms).
Engine `20260714093553_approvals_engine.sql` (gate-verified rolled-back — detail in DECISIONS): upsert_approval_workflow
(levels_json validated), request_approval (resolves active workflow by threshold; NULL=always; no match → required:false
so callers proceed unchanged; idempotent per open entity), act_on_approval (approvals:approve + level required_role
[ADMIN super-approver]; min_approvers; advances current_level; last→APPROVED, REJECT→REJECTED; one action per actor/level;
append-only audit), cancel_approval_request (requestor/admin), approval_status helper.
Escalation `20260714094049_approvals_escalation.sql`: escalate_expired_approvals (PENDING past expires_at → ESCALATED
+ audit; stays open/actionable). Scheduled pg_cron hourly (job approvals_escalation_hourly `0 * * * *`; ext enabled here).
UI `lib/features/approvals/` (clean-arch mirror of hr/; detail in DECISIONS): ONE ApprovalsRemoteDataSource (open+history
reads w/ requestor/workflow/actor embeds; act/cancel/request_approval RPCs), typed ApprovalFailure(8), controllers +
pendingApprovalsCountProvider (hub badge) + approvalDetailProvider.family. Pages: PendingApprovalsPage /approvals,
ApprovalDetailPage /approvals/:id (level ladder + timeline + entity deep link; Approve/Reject gated approvals:approve, Cancel),
ApprovalHistoryPage /approvals/history. Inventory-hub "Approvals" gated approvals:read w/ live count. Workflow-config UI
(gated approvals:update): ApprovalWorkflowsPage /approvals/workflows (by type, active switch) + WorkflowFormPage (type/
threshold/TTL + levels editor {role dropdown, min_approvers, add/reorder} → upsert_approval_workflow; soft-delete=is_active
false). analyze clean. A5 PO integration LIVE (migration po_approval_integration): submit_purchase_order raises
request_approval('PURCHASE_ORDER',po,grand_total); approve_purchase_order blocked (ERR_APPROVAL_REQUIRED) while chain
PENDING/ESCALATED/REJECTED. Inert w/o a workflow — regression-proven byte-for-byte. NEXT: wire other 7 types (deferred).
