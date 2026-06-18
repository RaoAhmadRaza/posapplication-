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
  features/migration_import/ (data layer — entities, repo, datasource, 4 use cases)
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

## Bugfixes Applied

- Product edit form: reactive ref.listen(productEditProvider) + _didSeed guard
- Product create: ref.invalidate(productsProvider) in controller.saveProduct
- RPC parsing: single-row Map (not List) for postStockMovement + ensureDefaultWarehouse
- Products card restored to Inventory hub (accidentally removed during Slice edits)
- Products screen filtering: unified search + category/brand/status into single composeable query path
  (search() now accepts filter params through the full chain — datasource → use case → repo → controller).
  Added brand filter dropdown to products page. Fixes: category-filter + search non-composition, missing
  brand filter.

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

- `ServerErrorFailure` — defined, never instantiated
- `cupertino_icons` — in pubspec, unused
- `RecoveryState` in core/error — semantic misplacement
- Profile loaded once (no pull-to-refresh)
- IMEI section not yet integrated into product edit form (SERIALIZED products)

## Migration Import — COMPLETE

Feature folder `lib/features/migration_import/` with full clean-arch stack.
Reuses InventoryFailure. 4 RPCs: migrate_import_categories/brands/products/stock.
M1: Datasource → Repository → 4 use cases.
M2: MigrationImportController (Notifier) with pickAndParse + run; CSV header→field pass-through.
M3: MigrationImportPage — 4 FK-ordered step cards, preview tables, expandable errors, on-screen logs panel.
Set-based RPCs (20260617120537) for categories/brands/products — single INSERT SELECT replaces per-row loop.
Stock RPC gets `set local statement_timeout = 0`. Products deduplicate barcode within batch + skip existing.
Chunk sizes: products 2000, stock 1000, others 500. Hub row in InventoryHubPage. Route /inventory/import-migration.
Bugfixes: bytes/null (withData:true + utf8.decode + path fallback), button hang (try/finally), jsonb params as List,
chunk failure tolerant (continue loop, accumulate totals), on-screen log panel replacing console prints.

## What's Next

Data migration import UI + full end-to-end flow. Sales module (POS bills,
checkout, invoice history) or Purchasing module.
