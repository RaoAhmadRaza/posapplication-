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
  features/dashboard/ (data + domain + controller — entity, model, datasource, repo, use case, controller)
    domain/entities/  17 (7 catalog + 10 stock-ops)
    domain/failures/  sealed InventoryFailure — 11 variants
    domain/usecases/  52 (23 catalog + 29 stock-ops)
    data/models/      17 (7 catalog + 10 stock-ops)
    data/datasources/ 1 (InventoryRemoteDataSource — all Supabase + RPCs)
    data/repositories/ 1 (InventoryRepositoryImpl)
    presentation/controllers/ 11 (5 catalog + 6 stock-ops)
    presentation/pages/ 20 (9 catalog + 10 stock-ops + hub)
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

Ordered, applied set lives in `supabase/migrations/` (filenames = the index); each migration's rationale
is logged in DECISIONS.md by date. Module coverage: auth/RBAC (init → auth_full_schema) · catalog + stock
engine/ops · sales foundation + returns + guards · dashboard · purchasing (PO/GRN/invoice/payment/returns +
supplier ledger) · customers/suppliers CRM + ledgers · M07 accounting (CoA/journal engine/vouchers/bank/
expenses/reports + all 6 auto-post money paths) · 2026-07-13 device per-tenant fingerprint fix + M09 repair
(repair_stock_movement_enum REPAIR_USE, repair_lifecycle_rpcs, repair_parts_consumption, repair_close_invoice,
inventory_service_type_guard) + inventory SERVICE non-stock guard.

## Bugfixes Applied
Full detail in DECISIONS.md. Headlines: product edit/create reactive-seed + invalidate; RPC single-row
Map parsing; unified products query path; canonical warehouse_id NULL stock read/write (2026-07-11 audit H);
per-tenant device fingerprint uniqueness — fixes login-time device-register 42501 (2026-07-13).

## Peripheral features — COMPLETE (detail in DECISIONS.md)

- **Barcode scanning** (`mobile_scanner`): shared `scanBarcode()`/`BarcodeScanPage`, platform-guarded; wired
  into products search, product form, IMEI lookup, count session.
- **Label printing** (`pdf`/`printing`/`barcode`): `LabelPdfService` A4 grid; multi-select → `LabelPrintPage`.
- **Notifications**: `notifications`(+prefs), `trg_low_stock_notify`, `NotificationsPage` + hub bell badge.
- **Bulk import** (`file_picker`/`csv`): `bulk_import_products` RPC + 3-step CSV `ImportProductsPage`.
- **Voice search** (`speech_to_text`): guarded mic in products search → `ProductsController.search()`.

## Known Issues

- Profile loaded once (no pull-to-refresh)
- IMEI section not yet integrated into product edit form (SERIALIZED products)

## Migration Import — COMPLETE
`lib/features/migration_import/` clean-arch (reuses InventoryFailure). 4 set-based RPCs
(migrate_import_categories/brands/products/stock); MigrationImportPage — 4 FK-ordered step cards.
Route /inventory/import-migration.

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

delivery_orders, loyalty_transactions, tax_rules table, payment_methods table, customer_groups,
pricing-tier engine, offline sync logic.

## Dashboard V1 — COMPLETE

D1 data layer: DashboardSummary entity (9 fields + nested RecentSale/TrendPoint/paymentBreakdown),
DashboardSummaryModel fromJson, DashboardRemoteDataSource .rpc('dashboard_summary'), repo +
DashboardFailure, LoadDashboardSummary use case, AsyncNotifier controller.
D2 UI: replaces placeholder — PermissionGate(reports:read), pull-to-refresh, KPI grid (6 cards:
Today's Sales/Transactions/Profit/Receivables/Stock Value/Low Stock), recent sales list (status chip →
invoice detail), quick-launch (POS/Inventory/History gated by matrix). D3 charts: fl_chart bar chart
(7-day trend, PKR tooltips) + pie chart (payment breakdown + legend).
Controller propagates failure as AsyncError (no zero-fill); page shows AppInlineBanner + retry on error.

### Dashboard V1 Deferred (Pipeline M10, Reporting phase)

payables + cash/bank balances, P&L/balance-sheet, drilldown reports, scheduled/email reports,
configurable KPI grid.

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
**Next:** **M10 Reporting** (P&L/BS drilldowns, scheduled reports); dashboard payables/cash KPIs
(need dashboard_summary fields); on-device click-through.

## M09 Repair & Service — COMPLETE (backend + Flutter)

Backend (prior session, applied + gate-verified): repair_jobs/repair_parts/repair_status_history +
repair_status_enum(9), RJ- series, REPAIR-SERVICE sentinel product (type=SERVICE) + 4200 Service Revenue,
REPAIR_USE movement type + its post_stock_movement gate branch. 7 RPCs (create_repair_job/assign_technician/
set_repair_diagnosis/change_repair_status/add_repair_part/remove_repair_part/close_repair_job). **7th balanced
money path**: close_repair_job builds the invoice DIRECTLY (own INSERT, session_id NULL — NOT create_sale) +
posts REPAIR_INVOICE journal explicitly (Cr 4200 labour / 4000 parts / 2100 tax, Dr 5000/Cr 1200 parts COGS at
captured cost). Parts deducted at add (REPAIR_USE); close recognizes cost only (no double-deduct). Full detail
in DECISIONS 2026-07-13.

Flutter (`lib/features/repair/`, full clean-arch mirroring purchasing): 3 entities + RepairStatus(9)/
RepairPriority(4) enums + result types; sealed RepairFailure (maps ERR_INVALID_TRANSITION/JOB_NOT_READY/
JOB_CLOSED/USE_CLOSE_TO_DELIVER); 10 usecases; ONE datasource (7 RPCs + reads embedding customers(name)/
products(name) + users technician load); repo impl → typed failures. RepairJobsController (list + status/
technician filters + all mutations) + repairJobDetailProvider family + techniciansProvider. Pages:
RepairKanbanPage /repair (LayoutBuilder — wide: drag-to-update status columns, narrow: grouped tappable list;
illegal drop → mapped failure), RepairIntakePage /repair/intake (lean customer picker reusing customersProvider,
device fields, priority, estimate, signature-URL), RepairDetailPage /repair/:id (diagnosis editor, parts add
[product picker]/remove, status history, cost summary, assign, Close & Invoice gated repair:update at READY →
invoice number). Also: TechnicianWorkloadPage /repair/workload (open-job counts per technician by status, tap →
technician-filtered kanban), RepairHistoryPage /repair/history (delivered/cancelled, client-side search by
job#/customer/imei, tap → read-only detail), RepairLabelPdfService QR device-tag label (job#+device+customer,
printed via Printing.layoutPdf from a detail-page action), and repair notifications (action_type=REPAIR, already
inserted by change_repair_status for the assigned technician) deep-link to /repair/:id from the existing inbox.
Kanban appbar → workload/history. Inventory-hub "Repair & Service" section gated repair:read. analyze clean.
SERVICE non-stock invariant enforced at post_stock_movement (migration inventory_service_type_guard, 2026-07-13) —
REPAIR-SERVICE / any SERVICE product rejected (ERR_SERVICE_NOT_STOCKED) on every stock path; stock-op pickers
(movement/adjustment/transfer/count/PO line) exclude type=SERVICE client-side (POS+catalog share the query, left as-is).
Signature capture (C2): SignaturePad shared widget (core/widgets, CustomPaint→PNG, no dep) in the Close & Invoice
dialog → uploadSignature to private 'signatures' bucket ('<tenant>/<repair>.png') → stored path passed to
close_repair_job; Detail "View Signature" via fresh 60s signed URL. Private bucket + RLS (migration
signatures_storage_policies, repair:update write / repair:read read), NO client AES (see DECISIONS). Storage calls
live in the repair datasource.
Pipeline C3: bulk_change_repair_status(uuid[], status, notes) loops change_repair_status (sole writer — full
validation + history + notify per job), collects failures → {succeeded, failed[{repair_id,error}]}; full clean-arch
chain (datasource/repo/usecase/controller bulkChangeStatus). Kanban multi-select: long-press card → select mode,
tap toggles, bottom _BulkBar (gated repair:update) → status picker (board statuses minus DELIVERED + CANCELLED) →
bulk RPC → snackbar succeeded + AlertDialog lists failed job#/error. Technician performance: technicianWorkloadProvider
now also emits delivered count + avg turnaround days (received→delivered, cancelled excluded, delivered-only techs
appear); surfaced on TechnicianWorkloadPage cards. (migration repair_bulk_status — pushed + gate-verified.)
Pipeline C4: change_repair_status redefined (isolated migration repair_customer_notifications) — after history insert,
logs a customer-facing outbound in NEW table communication_logs (tenant-RLS read; writes revoked from authenticated —
definer RPC + future M11 worker only) at milestones AWAITING_APPROVAL/READY; best-effort, non-blocking (own exception
block). Channel phone→SMS else email→EMAIL; no contact → no row (status still changes). template_code='REPAIR_STATUS' +
payload{job_number,status}; NO separate template table (body owned by M11 sender). SEND DEPENDENT on M11 provider/worker
— rows sit status='PENDING' until then. Backend-only (no client change). Pushed + gate-verified.
Pipeline C5 (migration repair_parts_tax): close_repair_job now taxes parts lines (removes R4 "parts tax-free").
Mirrors the LIVE create_sale EXACTLY — which applies EXCLUSIVE tax from a caller tax_pct and does NOT honor
tax_inclusive (phase premise corrected). Server-side basis = products.tax_rate; parts sell=cost*markup is pre-tax.
Parts tax_pct/tax_amount set (line_total stays exclusive per the labour-line convention) → v_parts_tax → 2100
Output Tax. COGS 5000/1200 at captured cost UNCHANGED; cost-tie preserved. Backend-only. Pushed + gate-verified
(dr=cr; 2100=labour+parts tax; 1200=Σ captured cost; trial balance true).
Pipeline C6 (migration repair_warranty_claim): WARRANTY_CLAIM re-repair workflow. NEW col repair_jobs.original_repair_id
(self-FK, parent link) + NEW account 5200 'Warranty Cost' (EXPENSE, seeded all tenants). open_warranty_claim (DELIVERED
+ in-warranty → linked RECEIVED re-repair reusing create_repair_job; original → WARRANTY_CLAIM; rejects non-delivered/
expired). close_warranty_claim: zero charge, NO invoice/revenue; parts consumed (REPAIR_USE); captured cost Dr 5200 /
Cr 1200 (account_code shape), reference_type REPAIR_WARRANTY, final_cost=0, READY→DELIVERED. Cost-tie: Dr 5200 == Σ
repair_parts.total_cost == Cr 1200. Backend-only. Pushed + gate-verified (0 invoices, 0 revenue lines, dr=cr, original
flipped, link set, trial balance true). Pre-existing gap noted: handle_new_user seeds no COA → future tenants lack 5200
until provisioning is fixed.
Repair UI completion (UI-only, additive): RepairJob.originalRepairId (isWarrantyClaim); datasource _jobCols selects
it + openWarrantyClaim/closeWarrantyClaim/loadRepairLinks (.or children+parent) → repo/usecases/controller. Detail
page READY close BRANCHES on originalRepairId: null → Close & Invoice (close_repair_job), not-null → "Close (Warranty
— no charge)" (close_warranty_claim). DELIVERED + in-warranty → "Warranty Claim" (repair:create) → issue dialog →
open_warranty_claim → nav to claim. Warranty link card (original↔claims, tappable). Live close breakdown (labour +
parts@markup + labour tax; balance→AR; parts output tax noted as added at close). Failures +NOT_DELIVERED/WARRANTY_
EXPIRED/OVERPAYMENT. AppTextField +onChanged (additive). C3 kanban multi-select + workload perf already present.
analyze clean; data path gate-verified. Device (button-tap) verify pending flutter run (user-driven).
DEFERRED: /repair/:id/edit (no update_repair_job RPC); intake signature; file_uploads/attachments audit rows;
board branch filter; customer-facing SMS/email; on-device click-through.

## M10 HR & Payroll — H1 Foundation ONLY (backend, in progress)
Migration `20260714073757_hr_foundation.sql` (applied prod + committed 624d898). Ships:
7 enums (employee/salary/attendance/leave×2/payroll×2_status); `employees` (tenant+branch scoped,
employee_code unique/tenant, salary_type+base_salary, bank+emergency+documents_json, soft-delete+version)
and `shifts` (name/start/end/grace/break) tables + indexes; RLS = tenant read + hr-gated writes
(auth_has_permission('hr','update')). NEW permission module `hr`: backfilled to all ADMIN roles (6 actions)
+ `trg_seed_hr_perms` AFTER INSERT trigger on roles (future ADMINs auto-get hr). CoA seeds (all existing
tenants, idempotent, is_system): 6200 Salary Expense (EXPENSE), 2120 Payroll Deductions Payable (LIABILITY),
1150 Employee Advances (ASSET). Codes H0-signed-off free; 5200 stays Warranty Cost (NOT reused).
GATE PASSED: 7 enums live; ADMIN hr_perms=30 (5 tenants×6); 3 accounts w/ correct enum types + is_system;
employees+shifts exist. FIX during push: `v.type::account_type_enum` cast — text→enum fails inside VALUES lists.
NEXT (not built): attendance/leaves/payroll_runs/payroll_items/salary_advances tables; payroll RPCs +
GL posting (Dr 6200 / Cr 2120+bank via post_journal); HR Flutter feature.
