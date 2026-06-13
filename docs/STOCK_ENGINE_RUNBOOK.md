# STOCK ENGINE RUNBOOK — Lumina POS (Slice B)

Migration: `supabase/migrations/20260613061924_stock_engine.sql`

## Architecture

- **stock_ledger** — IMMUTABLE, append-only. Every stock movement writes one row.
  No UPDATE/DELETE (enforced by trg_stock_ledger_immutable). Columns: tenant_id,
  product_id, variant_id, branch_id, warehouse_id, operation_type (stock_movement_type_enum),
  qty_change, cost_per_unit, total_cost, balance_after, avg_cost_after, reference_type,
  reference_id, notes, created_at, created_by.

- **stock_balance** — trigger-maintained materialized projection. Never written directly.
  Maintained by fn_apply_stock_ledger (AFTER INSERT on stock_ledger). Columns: tenant_id,
  branch_id, warehouse_id, product_id, variant_id, qty_on_hand, qty_reserved,
  qty_in_transit, avg_cost, reorder_point, last_stock_take, last_updated, version.

- **warehouses** — soft-deletable, per-branch. One default per branch enforced by
  partial unique index.

- **post_stock_movement** RPC — single write path (SECURITY DEFINER). Accepts
  branch_id, warehouse_id, product_id, variant_id, operation_type, qty_change,
  cost_per_unit, reference_type, reference_id, notes. Inserts into stock_ledger;
  the trigger computes balance_after, avg_cost_after, total_cost and upserts
  stock_balance. Blocks negative stock (P0001 'insufficient stock').

- **Negative stock is BLOCKED** — chk_stock_balance_on_hand CHECK (qty_on_hand >= 0)
  plus fn_apply_stock_ledger raises P0001 before going negative.

- **Weighted-avg cost** — computed in fn_apply_stock_ledger:
  `((old_qty * old_avg) + (new_qty_change * new_cost)) / (old_qty + new_qty_change)`

## Files

### Domain Entities
- `lib/features/inventory/domain/entities/stock_movement_type.dart`
- `lib/features/inventory/domain/entities/warehouse.dart`
- `lib/features/inventory/domain/entities/stock_balance.dart`
- `lib/features/inventory/domain/entities/stock_ledger_entry.dart`
- `lib/features/inventory/domain/entities/stock_level.dart`

### Domain Failures
- `lib/features/inventory/domain/failures/inventory_failure.dart`
  (+ InsufficientStockFailure, WarehouseHasStockFailure)

### Domain Repository (abstract)
- `lib/features/inventory/domain/repositories/inventory_repository.dart`
  (+13 stock method signatures)

### Domain Use Cases (13 stock + 3 reused)
- `lib/features/inventory/domain/usecases/load_warehouses.dart`
- `lib/features/inventory/domain/usecases/create_warehouse.dart`
- `lib/features/inventory/domain/usecases/update_warehouse.dart`
- `lib/features/inventory/domain/usecases/delete_warehouse.dart`
- `lib/features/inventory/domain/usecases/set_default_warehouse.dart`
- `lib/features/inventory/domain/usecases/ensure_default_warehouse.dart`
- `lib/features/inventory/domain/usecases/load_stock_balances.dart`
- `lib/features/inventory/domain/usecases/load_product_ledger.dart`
- `lib/features/inventory/domain/usecases/post_stock_movement.dart`
- `lib/features/inventory/domain/usecases/load_stock_levels.dart`

### Data Models
- `lib/features/inventory/data/models/warehouse_model.dart`
- `lib/features/inventory/data/models/stock_balance_model.dart`
- `lib/features/inventory/data/models/stock_ledger_entry_model.dart`
- `lib/features/inventory/data/models/stock_level_model.dart`

### Data Datasource
- `lib/features/inventory/data/datasources/inventory_remote_datasource.dart`
  (+10 stock methods: load/create/update/softDelete/setDefault/ensureDefault warehouse,
  loadStockBalances, loadProductLedger, loadStockLevels, postStockMovement)

### Data Repository
- `lib/features/inventory/data/repositories/inventory_repository_impl.dart`
  (+13 stock method impls + _mapError for stock failures)

### Presentation Controllers
- `lib/features/inventory/presentation/controllers/warehouses_controller.dart`
- `lib/features/inventory/presentation/controllers/stock_levels_controller.dart`

### Presentation Pages
- `lib/features/inventory/presentation/pages/warehouses_page.dart`
- `lib/features/inventory/presentation/pages/warehouse_form_page.dart`
- `lib/features/inventory/presentation/pages/stock_levels_page.dart`
- `lib/features/inventory/presentation/pages/product_stock_detail_page.dart`
- `lib/features/inventory/presentation/pages/stock_movement_form_page.dart`

### Router
- `lib/router.dart` (+5 routes: /inventory/warehouses, /create, /:warehouseId;
  /inventory/stock, /inventory/stock/:productId, /inventory/stock/movement)

### Hub
- `lib/features/inventory/presentation/pages/inventory_hub_page.dart`
  (+ Warehouses + Stock Levels rows)

### Migration
- `supabase/migrations/20260613061924_stock_engine.sql`

## RPC Signatures

| RPC | Returns | Params |
|-----|---------|--------|
| `post_stock_movement` | `stock_balance` (single row) | p_branch_id, p_warehouse_id, p_product_id, p_variant_id, p_operation_type, p_qty_change, p_cost_per_unit, p_reference_type, p_reference_id, p_notes |
| `soft_delete_warehouse` | void | p_id |
| `set_default_warehouse` | void | p_id |
| `ensure_default_warehouse` | `warehouses` (single row) | p_branch_id |

## Error Mapping (Flutter _mapError)

| PG Code | Message Contains | → Failure |
|---------|-----------------|-----------|
| P0001 | 'warehouse has stock' | WarehouseHasStockFailure |
| P0001 | 'stock' | InsufficientStockFailure |
| P0002 | — | NotFoundFailure |
| PGRST116 | — | NotFoundFailure |
| 42501 | — | PermissionDeniedFailure |
| 23505 | 'sku' or 'barcode' | DuplicateSkuFailure |

## Bugfixes Recorded

1. RPC returns single-row Map, not List — postStockMovement and ensureDefaultWarehouse
   were calling `.first` on a Map (NoSuchMethodError). Fixed: direct `as Map<String, dynamic>`.
2. Product edit form opened blank because didChangeDependencies ran before async load
   completed. Fixed: reactive `ref.listen(productEditProvider)` with `_didSeed` guard.
3. New products sometimes missing from list. Fixed: `ref.invalidate(productsProvider)`
   moved into `ProductEditController.saveProduct()` for guaranteed invalidation.
