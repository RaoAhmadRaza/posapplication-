# PROJECT STATE — Lumina POS

Last updated: 2026-06-13

## Stack & Architecture

Flutter + Supabase (Postgres + Auth + Storage). Clean architecture with plain Riverpod
(no codegen, no build_runner) and go_router. Dependency chain:

```
page → controller (Notifier<AsyncValue<T>>) → use case (Provider) → repository (abstract)
→ repository impl → remote datasource → supabase
```

Domain has entities + value objects + abstract repo + thin use cases (one call each).
Data has a single remote datasource holding all Supabase calls + repository impl that
maps AuthException → sealed AuthFailure. Presentation uses ConsumerStatefulWidgets.

## Project Structure

```
lib/
  main.dart app.dart router.dart
  core/
    design/tokens + theme + shared widgets (AppButton, AppTextField, AppCard, AppOtpField,
      AppInlineBanner, ResponsiveFormScaffold, PermissionGate)
    services/ (pin, device, mfa, audit, login_throttle)
  features/auth/         (domain/data/presentation — 21 pages, 12 controllers)
  features/inventory/
    domain/entities/      (7 catalog + 4 stock = 11)
    domain/failures/      (sealed InventoryFailure — 8 variants)
    domain/usecases/      (23 catalog + 13 stock = 36)
    data/models/          (7 catalog + 5 stock = 12)
    data/datasources/     (1: InventoryRemoteDataSource — all Supabase + RPCs)
    data/repositories/    (1: InventoryRepositoryImpl)
    presentation/controllers/ (5 catalog + 3 stock = 8)
    presentation/pages/   (9 catalog + 5 stock + hub = 15)
```

## Auth — Complete

All flows end-to-end. 33+ routes, auth redirect, StatefulShellRoute bottom nav.
RBAC (PermissionGate), branch selection, PIN lock + biometric, TOTP MFA, device
management, session management, security logs. go_router redirect as single source
of truth for navigation.

## Inventory — Product Catalog (Slice A) — COMPLETE

Categories, brands, products (with variants/images/pricing), barcode templates.
Trigram-accelerated ILIKE search. SKU auto-gen via DB trigger. Soft-delete via
SECURITY DEFINER RPCs. Permission-gated by inventory:* matrix.

## Stock Engine (Slice B) — COMPLETE

Migration: `20260613061924_stock_engine.sql`. Schema: warehouses, stock_balance
(trigger-maintained projection), stock_ledger (IMMUTABLE, append-only),
stock_movement_type_enum (9 values), fn_apply_stock_ledger (negative blocked,
weighted-avg cost), post_stock_movement + warehouse RPCs, RLS policies.

### Stock files under lib/features/inventory/

**Entities (4 new):**
- `stock_movement_type.dart` — enum SALE/PURCHASE_RECEIPT/RETURN_IN/RETURN_OUT/
  TRANSFER_OUT/TRANSFER_IN/ADJUSTMENT/SCRAP/OPENING_BALANCE + dbValue/fromDb
- `warehouse.dart` — id, tenantId, branchId, name, code, address, capacityNotes,
  isActive, isDefault
- `stock_balance.dart` — id, branchId, warehouseId, productId, variantId, qtyOnHand,
  qtyReserved, qtyInTransit, avgCost, reorderPoint, lastStockTake, lastUpdated
- `stock_ledger_entry.dart` — id, productId, variantId, branchId, warehouseId,
  operationType, qtyChange, costPerUnit, totalCost, balanceAfter, avgCostAfter,
  referenceType, referenceId, notes, createdAt
- `stock_level.dart` — composite: productId, productName, productSku, reorderPoint
  + balance fields; available getter, isLowStock

**Failures (+2):** InsufficientStockFailure, WarehouseHasStockFailure

**Models (5 new):** WarehouseModel, StockBalanceModel, StockLedgerEntryModel,
StockLevelModel, StockMovementType extension

**Datasource (+10 methods):** loadWarehouses, create/update/softDelete/setDefault/
ensureDefault warehouse, loadStockBalances, loadProductLedger, loadStockLevels
(join products!inner), postStockMovement (RPC)

**Repository:** +13 abstract methods + impl; _mapError extended (P0001 'warehouse
has stock' → WarehouseHasStockFailure, 'stock' → InsufficientStockFailure)

**Use cases (13 new):** LoadWarehouses, CreateWarehouse, UpdateWarehouse,
DeleteWarehouse, SetDefaultWarehouse, EnsureDefaultWarehouse, LoadStockBalances,
LoadProductLedger, PostStockMovement, LoadStockLevels, + 3 product detail reuses

**Controllers (3 new):**
- `warehouses_controller.dart` — AsyncNotifier, build() ensures default → loads
- `stock_levels_controller.dart` — AsyncNotifier, build() finds default warehouse,
  loads levels; load({warehouseId})
- `stock_levels_controller.dart` — reused by forms; no separate movement controller

**Pages (5 new):**
- `warehouses_page.dart` — AppCards with name/code/Default badge/active chip;
  Set Default + Delete gated by PermissionGate
- `warehouse_form_page.dart` — name/code/address/capacityNotes + isActive switch
- `stock_levels_page.dart` — search (300ms debounce), warehouse selector, low-stock
  toggle; product rows with 4 metrics + low-stock amber badge
- `product_stock_detail_page.dart` — per-warehouse table + ledger history
- `stock_movement_form_page.dart` — product/warehouse/target/cost/notes; delta
  preview; OPENING_BALANCE RPC; InsufficientStockFailure inline banner

**Routes (5 new):** `/inventory/warehouses`, `/create`, `/:warehouseId`;
`/inventory/stock`, `/inventory/stock/:productId`, `/inventory/stock/movement`

**Hub:** "Warehouses" + "Stock Levels" rows active; "Transfer" row stays Coming Soon.

## Database Migrations

| Migration | Contents |
|-----------|----------|
| `20260609000000_init.sql` | tenants, roles, users + trigger v1 + seeds |
| `20260609000001_signup_provisioning.sql` | business_name → new tenant trigger |
| `20260609000002_auth_full_schema.sql` | branches, assignments, permissions, devices, sessions, mfa_configs, audit_logs; RLS helpers |
| `20260611000000_failed_login_rpc.sql` | increment/reset_failed_login RPCs |
| `20260611000001_product_catalog.sql` | categories, brands, products, variants, images, pricing, barcode templates |
| `20260611163739_product_sku_and_search.sql` | pg_trgm, SKU auto-gen, search_products RPC |
| `20260613061924_stock_engine.sql` | warehouses, stock_balance, stock_ledger, enums, triggers, RPCs, RLS, seeds |

## Bugfixes Applied

- Product edit form: didChangeDependencies → ref.listen(productEditProvider) with
  _didSeed guard so form populates reactively when async load completes
- Product create: ref.invalidate(productsProvider) in controller.saveProduct
  ensures list refreshes after every save
- RPC parsing: postStockMovement + ensureDefaultWarehouse treat .rpc() result as
  single-row Map (not List) — removed .first calls that crashed on success

## Known Issues

- `ServerErrorFailure` — defined, never instantiated
- `cupertino_icons` — in pubspec, unused
- `RecoveryState` in `core/error/auth_failure.dart` — semantic misplacement
- Profile loaded once on mount (no pull-to-refresh)

## What's Next

Slice C: stock transfers, stock adjustments, stock counts, IMEI tracking, scrap,
valuation. Remaining stock_balance fields (qty_in_transit populated when transfer
logic ships). stock_ledger partitioning deferred.
