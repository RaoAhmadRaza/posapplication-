# PROJECT STATE — Lumina POS

Last updated: 2026-06-18

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

Migration `20260613075616_stock_ops.sql`. New tables: stock_adjustments, stock_transfers,
stock_transfer_items, stock_counts, stock_count_items, imei_records, inventory_settings,
number_series. New enums (4): adjustment_reason, stock_transfer_status, stock_count_status,
imei_status. New RPCs (10): create/approve_adjustment, create/dispatch/receive/cancel_transfer,
open/record/complete_count, register_imei. All ops post through Slice B ledger.

### Slice C Flutter files

**Entities (6 new + 4 enums):** StockAdjustment, StockTransfer, StockTransferItem,
StockCount, StockCountItem, ImeiRecord + AdjustmentReason, StockTransferStatus,
StockCountStatus, ImeiStatus

**Failures (+3):** DuplicateImeiFailure, ApprovalRequiredFailure, InvalidTransitionFailure

**Models (6 new):** StockAdjustmentModel, StockTransferModel, StockTransferItemModel,
StockCountModel, StockCountItemModel, ImeiRecordModel

**Datasource (+20 methods):** adjustments (load/create/approve), transfers (load/loadItems/
create/dispatch/receive/cancel), counts (load/loadItems/open/recordItem/complete),
imei (load/register), settings (load/updateThreshold)

**Repository:** +22 abstract + impl; _mapError: 23505+imei→DuplicateImei,
22000→InvalidTransition

**Use cases (16 new):** LoadAdjustments, CreateAdjustment, ApproveAdjustment,
LoadTransfers, LoadTransferItems, CreateTransfer, DispatchTransfer, ReceiveTransfer,
CancelTransfer, LoadCounts, LoadCountItems, OpenCount, RecordCountItem, CompleteCount,
LoadImei, RegisterImei, LoadInventorySettings, UpdateApprovalThreshold

**Controllers (3 new):** AdjustmentsController, TransfersController, CountsController,
ImeiController

**Pages (7 new):** AdjustmentsPage, AdjustmentFormPage, TransfersPage, TransferFormPage,
TransferReceivePage, CountsPage, CountSessionPage, ImeiLookupPage

**Routes (+13):** `/inventory/adjustments`, `/create`; `/inventory/transfers`, `/create`,
`/:id/receive`; `/inventory/counts`, `/:id`; `/inventory/imei`

**Hub:** All rows active (Products, Barcode Templates, Categories, Brands, Warehouses,
Stock Levels, Adjustments, Transfers, Stock Counts, IMEI Lookup)

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
| `20260618114258_sales_foundation.sql` | customers, cashier_sessions, invoices, invoice_items, payments + RLS, INVOICE number_series seed, create_sale/open_cashier_session/close_cashier_session RPCs, invoice-immutability trigger |

## Bugfixes Applied

- Product edit form: reactive ref.listen(productEditProvider) + _didSeed guard
- Product create: ref.invalidate(productsProvider) in controller.saveProduct
- RPC parsing: single-row Map (not List) for postStockMovement + ensureDefaultWarehouse
- Products card restored to Inventory hub (accidentally removed during Slice edits)
- Products screen filtering: unified search + category/brand/status into single composeable query path
  (search() now accepts filter params through the full chain — datasource → use case → repo → controller).
  Added brand filter dropdown to products page. Fixes: category-filter + search non-composition, missing
  brand filter.
- Stock read path: stockLevelsController was filtering loadStockLevels by default warehouse UUID, but all
  stock_balance rows use warehouse_id IS NULL (canonical default-location representation). Controller now
  passes warehouseId: null; datasource isFilter('warehouse_id', null) matches NULL rows. POS onTap now
  gates on (stock?.available ?? 0) > 0 — null/zero stock = not addable + greyed. SearchResultTile: spacing
  before price + dividers between tiles.
- Products card stock: was showing product.reorderPoint labeled "Stock:" (all=10, migration default).
  Now shows real stock_balance.qty_on_hand via loadProductsStock (branch-wide eq branch_id +
  isFilter warehouse_id null), merged into Product.qtyOnHand. Card renders Out/Low/—/N. Controller
  ref.watch currentBranchProvider for rebuild on branch resolve; throws on stock failure (visible).

## Barcode Scanning — Wired

- Package: `mobile_scanner: ^7.2.0`
- `lib/core/services/scanner_support.dart` — `bool get barcodeScanSupported` (true only on iOS/Android, not web)
- `lib/core/widgets/barcode_scan_page.dart` — shared reusable scanner (293 lines): `scanBarcode(context, title:)` helper + `BarcodeScanPage` widget (camera preview, scan-window overlay, torch toggle, 1.5s debounce, manual-entry sentinel, permission-denied screen)
- Platform permissions: `NSCameraUsageDescription` in iOS Info.plist, `CAMERA` + `uses-feature` in Android manifest
- Wired into 4 inventory screens (scan buttons gated by `barcodeScanSupported`; desktop/web degrade silently):
  - Products search — sets field + triggers debounced search
  - Product form barcode field — sets `_barcodeCtrl.text`
  - IMEI lookup — sets field + calls `_search()`
  - Count session — matches scanned SKU/barcode to count line, scrolls + focuses quantity input; "Not in this count" banner if no match

## Barcode Templates — Label Printing (Workflow §6.6) — COMPLETE

- Packages: `pdf`, `printing`, `barcode`
- `lib/features/inventory/data/services/label_pdf_service.dart` — renders labels on A4 grid per BarcodeTemplate mm dimensions (CODE128/EAN13/QR, SKU fallback on null barcode, EAN13 validates 13-digit else degrades to CODE128)
- Products page: multi-select mode gated by `PermissionGate(module:'inventory', action:'export')` — ADMIN only; bottom bar with count + "Choose Template" → `/inventory/labels`
- `lib/features/inventory/presentation/pages/label_print_page.dart` — template picker (defaults to `isDefault`), per-product +/- quantity controls, "Preview / Print" via `Printing.layoutPdf`
- Barcode Templates are no longer CRUD-only — they produce actual PDF labels end-to-end

## Notifications (§3.13) — Low-Stock Alerts + In-App Inbox — COMPLETE

- Migration `20260615082538_notifications_low_stock.sql`: `notifications` + `notification_preferences` tables
- DB trigger `trg_low_stock_notify` on `stock_balance` fires on qty_on_hand crossing below effective reorder_point (stock_balance override else product.reorder_point); deduped per product+branch while unread; inserts per tenant ADMIN respecting preferences
- `mark_notification_read(p_id)` SECURITY DEFINER RPC
- `lib/features/notifications/` clean-arch feature folder: `AppNotification` entity (18 columns + 3 enums), `NotificationModel`, `NotificationRemoteDataSource` (load/unreadCount/markRead/markAllRead), `NotificationRepository`, `NotificationsController` (AsyncNotifier) + `unreadCountProvider` (FutureProvider)
- `NotificationsPage` — list with priority chip, unread dot, time-ago, tap → deep-links to `/inventory/stock/:actionId`, "Mark All Read"
- Inventory hub AppBar: bell icon + unread badge (destructive counter, 99+ cap) → `/inventory/notifications`

## Bulk Product Import — COMPLETE

- Migration `20260616100723_bulk_import_products.sql`: `bulk_import_products(p_rows jsonb)` SECURITY DEFINER RPC — per-row try/catch, `{ok, failed, errors[]}`, resolves category/brand by name, SKU auto-gen, gated by `inventory:create`
- Packages: `file_picker: ^3.0.4`, `csv: ^8.0.0`
- `lib/features/inventory/presentation/pages/import_products_page.dart` — 3-step flow: pick .csv, column-mapping with smart auto-map + preview table, import with result summary
- Datasource + use case + controller method `bulkImport(jsonPayload)` wired through clean-arch layers
- Products page: upload icon button (PermissionGate `inventory:create`) → `/inventory/import`

## Voice Search — Wired

- Package: `speech_to_text: ^7.4.0`
- `lib/core/services/voice_support.dart` — `bool get voiceSearchSupported` (iOS/Android only)
- `lib/core/services/voice_input_service.dart` — wraps `SpeechToText`: lazy init, `listen()` returns `Future<String?>`, 5s timeout, streams partial → `onPartial` callback, dictation mode
- Products search: mic icon (gated by `voiceSearchSupported`); while listening shows red mic + "Listening… '[partial]'" subtitle; partial streams into search field; final result triggers `ProductsController.search()`
- Native permissions: `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription` in Info.plist, `RECORD_AUDIO` in Android manifest

## Known Issues

- `cupertino_icons` — in pubspec, unused
- `RecoveryState` in core/error — semantic misplacement
- Profile loaded once (no pull-to-refresh)
- IMEI section not yet integrated into product edit form (SERIALIZED products)
- roles + tenants RLS `using (true)` — cross-tenant read of tenant names / role hierarchy
- loadProducts() unbounded — silently truncated by Supabase's ~1000-row cap at 8,294 products

## Migration Import — COMPLETE

Feature folder `lib/features/migration_import/` with full clean-arch stack.
Reuses InventoryFailure. 4 RPCs: migrate_import_categories/brands/products/stock.
Set-based RPCs for categories/brands/products; products deduplicate barcode within batch.
M3: MigrationImportPage — 4 FK-ordered step cards, preview tables, expandable errors.
Route /inventory/import-migration. Hub row in InventoryHubPage.

## Sales V1 — Core COMPLETE

DB foundation (S1): customers, cashier_sessions, invoices, invoice_items, payments + RLS; RPCs create_sale,
open/close_cashier_session, create_sales_return, void_invoice; invoice-immutability trigger; INVOICE
number_series seed. Data+domain (S2): 7 entities, SalesFailure, repo, 6 models, datasource, 10 use cases,
4 controllers. POS terminal (S3): product search+scan, cart qty-steppers, customer picker (S4),
multi-payment/credit (S4), tax at checkout (R5), hold/resume (R6A), void (R6B), return (S6). Session
lifecycle fix (SF1): SessionController DB-backed, Resume/Close card, variance summary, staleness chip.
Polish (SF2): negative-float validation, "PKR" labels, receipt WhatsApp share fix. Autosave (SF3):
WidgetsBindingObserver auto-holds non-empty cart on app pause ("Auto-saved HH:MM"), resume banner
"Auto-saved cart available — tap Resume". POS fixes (SF4): createCustomer tenant_id fix; narrow layout
products-full-body + cart bottom-sheet (FAB); stock qty chip on product cards (via stockLevelsProvider);
live session sales via invoices sum (banner). Session
open/close (S3). Sales history+detail (S5) with Reprint/Share. Receipt PDF (S3). Permission gating on
all routes + bottom-nav (R2). Operation-aware post_stock_movement gate applied (SALE/RETURN_IN accept
sales perms). create_sale enforces min_selling_price + credit_limit, overridable by sales:approve.
Bugfix round: cart sheet watches provider live (SF4 fix 1), banner loads on entry+session change (fix 2),
same-product dedup (fix 3), product search capped at 50 (fix 4).
Audit fix (2026-06-24): close_cashier_session now gated on sales:create + owner-only (session.cashier_id
= auth.uid()), overridable by sales:approve — was the one ungated sales RPC.

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

## What's Next

Purchasing module.
