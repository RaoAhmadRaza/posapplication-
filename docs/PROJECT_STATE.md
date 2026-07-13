# PROJECT STATE — Lumina POS

Last updated: 2026-07-11

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

| Migration | Contents |
|-----------|----------|
| `20260609000000_init.sql` | tenants, roles, users, trigger v1, seeds |
| `20260609000001_signup_provisioning.sql` | business_name → new tenant trigger |
| `20260609000002_auth_full_schema.sql` | branches, assignments, permissions, devices, sessions, mfa, audit_logs |
| `20260611000000_failed_login_rpc.sql` | increment/reset_failed_login RPCs |
| `20260611000001_product_catalog.sql` | catalog schema + RLS |
| `20260611163739_product_sku_and_search.sql` | pg_trgm, SKU auto-gen |
| `20260613061924_stock_engine.sql` | warehouses, stock_balance, stock_ledger, enums, triggers, RPCs |
| `20260613075616_stock_ops.sql` | adjustments, transfers, counts, imei, number_series, settings, RPCs |
| `20260611173542_fix_softdelete_rls.sql` | collapse duplicate catalog UPDATE policies |
| `20260612160453_inventory_softdelete_rpcs.sql` | soft_delete_brand/category/product SECURITY DEFINER RPCs |
| `20260615082538_notifications_low_stock.sql` | notifications + notification_preferences + low-stock trigger |
| `20260616100723_bulk_import_products.sql` | bulk_import_products RPC |
| `20260617103129 / 120537 / 121221 / 122153 / 122619` | migration-import RPCs + set-based + counts/idempotent/numfix fixes |
| `20260618114258_sales_foundation.sql` | customers, cashier_sessions, invoices, invoice_items, payments + RLS, INVOICE number_series seed, create_sale/open_cashier_session/close_cashier_session RPCs, invoice-immutability trigger |
| `20260618174821_sales_returns.sql` | create_sales_return RPC |
| `20260619115907_post_stock_movement_operation_aware.sql` | SALE/RETURN_IN accept sales perms |
| `20260619124544_create_sale_price_credit_guards.sql` | min_selling_price + credit_limit guards (overridable sales:approve) |
| `20260619124958_held_sales.sql` | held_sales table (hold/resume) |
| `20260619125510_void_invoice.sql` | void_invoice RPC |
| `20260619180707_dashboard_summary.sql` | dashboard_summary RPC |
| `20260624185804_close_cashier_session_permission_gate.sql` | sales:create gate + owner-only |
| `20260710132545_tenant_scope_roles_tenants_rls.sql` | tenant-scoped RLS on roles + tenants (fixes cross-tenant read) |
| `20260710134809_customers_mutation_permissions.sql` | customers perm module; insert/update/delete gated customers:* |
| `20260710143731_revoke_next_number_from_authenticated.sql` | revoke next_number from authenticated (SECURITY DEFINER callers unaffected) |
| `20260711094601_purchase_foundation_suppliers_perms.sql` | suppliers table + purchase perm module + PO/GRN/PV number series |
| `20260711094922_purchase_orders_and_rpcs.sql` | purchase_orders(+items) + create/update/submit/approve/cancel RPCs |
| `20260711100014_purchase_grn_receive.sql` | grns(+items) + receive_goods RPC |
| `20260711101802_fix_receive_goods_enum_cast.sql` | receive_goods PO-status enum-cast fix |
| `20260711102138_purchase_invoices_and_payments.sql` | purchase_invoices + supplier_payments + create_invoice/record_payment RPCs |
| `20260711102631_purchase_supplier_ledger_aging.sql` | supplier_ledger + payables_aging RPCs |
| `20260711111535_fix_receive_goods_imei_status.sql` | serialized receipt imei status IN_STOCK→AVAILABLE fix |
| `20260711124610_purchase_return_number_series_enum.sql` | add PURCHASE_RETURN to number_series_type_enum |
| `20260711124716_purchase_returns.sql` | purchase_returns(+items) + create_purchase_return RPC |
| `20260711141631_customer_ledger_receivables_aging.sql` | customer_ledger + receivables_aging RPCs (customers:read) |
| `20260711145841_fix_receivables_aging_and_ledger_basis.sql` | aging due-date from credit_terms; ledger outstanding = invoice balance |
| `20260711174723 / 175654 / 181843 / 183026` | M07 accounting: CoA+fiscal+tax+ledger_accounts (+acct_id/current_fiscal_period, accounting perm), journal engine (journal_entries/lines, post_journal/reverse_journal, immutability+period+balance triggers), vouchers/bank/expenses (create_voucher/create_expense), reports (trial_balance/profit_loss/balance_sheet/account_ledger) |
| `20260711182456_fix_bank_accounts_client_grant.sql` | grant insert/update on bank_accounts to authenticated (client-CRUD policies were dead — no table grant) |
| `20260711184605 / 185637 / 192129` | create_sale auto-posts SALE journal (Dr cash/AR, Cr revenue/tax, Dr COGS/Cr inventory, ungated) + journal reference-uniqueness index; record_customer_payment (credit settlement, Dr cash/bank Cr AR, PARTIALLY_PAID/PAID) — 185637 briefly regressed the GL hook, 192129 restored it as canonical (see DECISIONS) |
| `20260711200843 / 201211 / 201702` | purchase-side auto-post hooks: SUPPLIER_PAYMENT (Dr AP, Cr cash/bank), PURCHASE_INVOICE (Dr inventory/input-tax, Cr AP), PURCHASE_RETURN (Dr AP, Cr inventory at stock cost basis, Cr input-tax) — completes A5, all 5 money paths live |
| `20260713094705_devices_tenant_scoped_fingerprint.sql` | device fingerprint uniqueness per-tenant (uq_devices_tenant_fingerprint), replaces global index — fixes cross-tenant upsert 42501 at login |
| `20260713094744_repair_stock_movement_enum.sql` | adds REPAIR_USE to stock_movement_type_enum (M08 repair groundwork) |

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
**Next:** **M10 Reporting** (P&L/BS drilldowns, scheduled reports) or M08/M09; dashboard payables/cash KPIs
(need dashboard_summary fields); on-device click-through.
