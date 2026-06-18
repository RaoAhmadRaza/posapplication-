# STOCK OPS RUNBOOK — Lumina POS (Slice C)

Migration: `supabase/migrations/20260613075616_stock_ops.sql`

## Architecture

All stock operations (adjustments, transfers, counts, IMEI) post through the Slice B
`post_stock_movement` SECURITY DEFINER RPC. Clients NEVER write stock_balance/stock_ledger
directly. Negative stock is blocked at the ledger trigger level.

### Adjustments
- **create_stock_adjustment** RPC: inserts row; if below approval threshold → auto-posts
  via post_stock_movement (ADJUSTMENT or SCRAP depending on reason). If above threshold →
  sets requires_approval=true, leaves unposted.
- **approve_stock_adjustment** RPC (inventory:approve): posts the movement, marks approved.
- Reasons: DAMAGE, THEFT, EXPIRED, RECOUNT, OPENING_BALANCE, WRITE_OFF, OTHER.
- WRITE_OFF/DAMAGE/THEFT/EXPIRED with negative qty post as SCRAP movement type.
- Threshold from inventory_settings.adjustment_approval_threshold (0 = never require).

### Transfers
- **create_stock_transfer** RPC (inventory:create): inserts DRAFT transfer + items.
  Number via next_number('STOCK_TRANSFER') with TRF- prefix.
- **dispatch_stock_transfer** RPC (inventory:update): posts TRANSFER_OUT (-qty) per item
  from source; status → IN_TRANSIT.
- **receive_stock_transfer** RPC (inventory:update): posts TRANSFER_IN (+qty_received)
  per item to destination; status → PARTIALLY_RECEIVED or RECEIVED. Supports partial receipt.
- **cancel_stock_transfer** RPC (inventory:update): DRAFT → CANCELLED directly;
  IN_TRANSIT → returns items via TRANSFER_IN then CANCELLED.
- Transfers visible to users on either branch (RLS: from_branch_id OR to_branch_id).

### Stock Counts
- **open_stock_count** RPC (inventory:update): snapshots current system_qty from
  stock_balance into stock_count_items for matching products; status → IN_PROGRESS.
  Number via next_number('STOCK_COUNT') with CNT- prefix.
- **record_count_item** RPC (inventory:update): sets counted_qty, computes variance +
  variance_cost (using current avg_cost); updates progress counters.
- **complete_stock_count** RPC (inventory:approve): posts variance as ADJUSTMENT movements
  per item with variance ≠ 0; stamps last_stock_take on affected balances; status → COMPLETED.

### IMEI Records
- **register_imei** RPC (inventory:create): inserts with global unique check
  (uq_imei_records_imei); optionally posts +1 OPENING_BALANCE (p_post_stock flag).
- IMEI lifecycle: AVAILABLE→SOLD/RETURNED/TRANSFERRED/SCRAPPED/RESERVED/IN_TRANSIT
  (status changes via Sales/Purchasing RPCs later).
- imei_id FK added to stock_ledger (Slice B gap fix).

### Inventory Settings
- **inventory_settings** table (one row per tenant): adjustment_approval_threshold,
  allow_negative_stock.
- RLS: read = authenticated, update = settings:update.
- Update via direct table UPDATE (not an RPC — RLS gates it).

### Number Series
- **number_series** table (tenant+branch+type unique): auto-incrementing document numbers.
- **next_number** RPC (SECURITY DEFINER, SELECT FOR UPDATE): thread-safe increment.
- Seeded prefixes: TRF- (STOCK_TRANSFER), CNT- (STOCK_COUNT).
- Reusable for INVOICE, PURCHASE_ORDER, GRN, etc. (Sales/Purchasing modules).

## Files — Slice C (Stock Ops)

### Domain Entities (10)
- `lib/features/inventory/domain/entities/adjustment_reason.dart`
- `lib/features/inventory/domain/entities/stock_transfer_status.dart`
- `lib/features/inventory/domain/entities/stock_count_status.dart`
- `lib/features/inventory/domain/entities/imei_status.dart`
- `lib/features/inventory/domain/entities/stock_adjustment.dart`
- `lib/features/inventory/domain/entities/stock_transfer.dart`
- `lib/features/inventory/domain/entities/stock_transfer_item.dart`
- `lib/features/inventory/domain/entities/stock_count.dart`
- `lib/features/inventory/domain/entities/stock_count_item.dart`
- `lib/features/inventory/domain/entities/imei_record.dart`

### Domain Failures
- `lib/features/inventory/domain/failures/inventory_failure.dart` (+3: DuplicateImei,
  ApprovalRequired, InvalidTransition)

### Domain Use Cases (16)
- `lib/features/inventory/domain/usecases/load_adjustments.dart`
- `lib/features/inventory/domain/usecases/create_adjustment.dart`
- `lib/features/inventory/domain/usecases/approve_adjustment.dart`
- `lib/features/inventory/domain/usecases/load_transfers.dart`
- `lib/features/inventory/domain/usecases/load_transfer_items.dart`
- `lib/features/inventory/domain/usecases/create_transfer.dart`
- `lib/features/inventory/domain/usecases/dispatch_transfer.dart`
- `lib/features/inventory/domain/usecases/receive_transfer.dart`
- `lib/features/inventory/domain/usecases/cancel_transfer.dart`
- `lib/features/inventory/domain/usecases/load_counts.dart`
- `lib/features/inventory/domain/usecases/load_count_items.dart`
- `lib/features/inventory/domain/usecases/open_count.dart`
- `lib/features/inventory/domain/usecases/record_count_item.dart`
- `lib/features/inventory/domain/usecases/complete_count.dart`
- `lib/features/inventory/domain/usecases/load_imei.dart`
- `lib/features/inventory/domain/usecases/register_imei.dart`
- `lib/features/inventory/domain/usecases/load_inventory_settings.dart`
- `lib/features/inventory/domain/usecases/update_approval_threshold.dart`

### Data Models (6)
- `lib/features/inventory/data/models/stock_adjustment_model.dart`
- `lib/features/inventory/data/models/stock_transfer_model.dart`
- `lib/features/inventory/data/models/stock_transfer_item_model.dart`
- `lib/features/inventory/data/models/stock_count_model.dart`
- `lib/features/inventory/data/models/stock_count_item_model.dart`
- `lib/features/inventory/data/models/imei_record_model.dart`

### Data Datasource
- `lib/features/inventory/data/datasources/inventory_remote_datasource.dart`
  (+20 stock-ops methods)

### Data Repository
- `lib/features/inventory/data/repositories/inventory_repository_impl.dart`
  (+22 stock-ops impl + _mapError extensions)

### Presentation Controllers (4)
- `lib/features/inventory/presentation/controllers/adjustments_controller.dart`
- `lib/features/inventory/presentation/controllers/transfers_controller.dart`
- `lib/features/inventory/presentation/controllers/counts_controller.dart`
- `lib/features/inventory/presentation/controllers/imei_controller.dart`

### Presentation Pages (8)
- `lib/features/inventory/presentation/pages/adjustments_page.dart`
- `lib/features/inventory/presentation/pages/adjustment_form_page.dart`
- `lib/features/inventory/presentation/pages/transfers_page.dart`
- `lib/features/inventory/presentation/pages/transfer_form_page.dart`
- `lib/features/inventory/presentation/pages/transfer_receive_page.dart`
- `lib/features/inventory/presentation/pages/counts_page.dart`
- `lib/features/inventory/presentation/pages/count_session_page.dart`
- `lib/features/inventory/presentation/pages/imei_lookup_page.dart`

### Router + Hub
- `lib/router.dart` (+13 routes)
- `lib/features/inventory/presentation/pages/inventory_hub_page.dart` (all rows active)

## Error Mapping (Flutter _mapError)

| PG Code | Message Contains | → Failure |
|---------|-----------------|-----------|
| 23505 | 'imei' | DuplicateImeiFailure |
| 22000 | — | InvalidTransitionFailure |
| P0001 | 'warehouse has stock' | WarehouseHasStockFailure |
| P0001 | 'stock' | InsufficientStockFailure |
| P0002 | — | NotFoundFailure |
| PGRST116 | — | NotFoundFailure |
| 42501 | — | PermissionDeniedFailure |

## RPC Signatures

| RPC | Returns | Summary |
|-----|---------|---------|
| `create_stock_adjustment` | stock_adjustments | Inserts row; auto-posts if below threshold |
| `approve_stock_adjustment` | void | Posts movement, marks approved |
| `create_stock_transfer` | stock_transfers | Creates DRAFT + items (p_items jsonb) |
| `dispatch_stock_transfer` | void | Posts TRANSFER_OUT per item |
| `receive_stock_transfer` | void | Posts TRANSFER_IN per item (p_received jsonb) |
| `cancel_stock_transfer` | void | Returns stock if IN_TRANSIT, sets CANCELLED |
| `open_stock_count` | stock_counts | Snapshots system_qty, IN_PROGRESS |
| `record_count_item` | void | Sets counted_qty + variance |
| `complete_stock_count` | void | Posts variance ADJUSTMENTs, COMPLETED |
| `register_imei` | imei_records | Global-unique insert; optional +1 stock post |
| `next_number` | text | Thread-safe auto-incrementing document number |
