# Inventory Feature Test Catalog

**Catalogued:** ✓ | **Pages:** 24 | **Routes:** 20 | **Test Cases:** 24 (summary table format)

---

## Inventory Pages Quick Reference

| # | Page | Route | Elements | Guard | RPC | Sample Test Case |
|---|---|---|---|---|---|---|
| 1 | InventoryHubPage | /inventory | Hub nav rows | NONE | Navigation only | Navigation to all hubs works |
| 2 | CategoriesPage | /inventory/categories | List + search + filter + edit {id} + delete | inventory:read | categoriesProvider | List renders all categories; filter by parent works |
| 3 | CategoryFormPage | /inventory/categories/create | Form: name, parent, desc, sort order, active → save | inventory:create | categoriesProvider.notifier.save | Create new category; RPC saves to DB; navigate to list |
| 4 | BrandsPage | /inventory/brands | List + edit {id} + delete | inventory:read | brandsProvider | List renders brands; tap brand navigates to edit form |
| 5 | BrandFormPage | /inventory/brands/create | Form: name, logo, desc, active → save | inventory:create | brandsProvider.notifier.save | Form pre-filled in edit mode; submit RPC fires |
| 6 | ProductsPage | /inventory/products | Search (query/barcode/voice) + filter (category/brand/status) + scan + multi-select + print/import | inventory:read | productsProvider.notifier.search | Search by name; filter by brand; scan barcode works |
| 7 | ProductFormPage | /inventory/products/create | Form: core fields + variants + images + pricing tiers → save | inventory:create | productEditProvider.notifier.saveProduct | Create with variants; image upload; pricing tiers save |
| 8 | BarcodeTemplatesPage | /inventory/barcode-templates | List + edit {id} | inventory:create | barcodeTemplatesProvider | List renders templates; click to edit |
| 9 | BarcodeTemplateFormPage | /inventory/barcode-templates/create | Form: name, format, dims, layout, default → save | inventory:create | barcodeTemplatesProvider.notifier.save | Form validates dims; save creates template |
| 10 | WarehousesPage | /inventory/warehouses | List + set-default + delete | inventory:create | warehousesProvider | Set default warehouse; delete if not in use |
| 11 | WarehouseFormPage | /inventory/warehouses/create | Form: name, code, address, capacity, active → save | inventory:create | warehousesProvider.notifier.save | Create warehouse; code must be unique |
| 12 | StockLevelsPage | /inventory/stock | List search (SKU/name) + filter warehouse + low-stock indicator → detail | inventory:read | stockLevelsProvider | Filter by warehouse; identify low stock items |
| 13 | ProductStockDetailPage | /inventory/stock/{productId} | Warehouse table (on-hand qty) + ledger history | inventory:read | loadStockBalancesUseCase / loadProductLedgerUseCase | Verify on-hand balance; view ledger movements |
| 14 | StockMovementFormPage | /inventory/stock/movement | Form: product picker + target qty + cost + notes → post | inventory:read | postStockMovementUseCase | Select product; enter qty; RPC posts to GL |
| 15 | AdjustmentsPage | /inventory/adjustments | List + filter pending → approve/reject | inventory:update | adjustmentsProvider | List pending adjustments; approve one → balance updates |
| 16 | AdjustmentFormPage | /inventory/adjustments/create | Form: product + warehouse + qty + reason + notes → create | inventory:update | adjustmentsProvider.notifier.create | Create adjustment; RPC posts stock move + GL posting |
| 17 | TransfersPage | /inventory/transfers | List + filter direction (all/outgoing/incoming) + dispatch/receive/cancel | inventory:create | transfersProvider | Filter incoming transfers; tap to receive |
| 18 | TransferFormPage | /inventory/transfers/create | Form: source branch + dest branch + warehouses + line-items → create | inventory:create | transfersProvider.notifier.create | Create transfer with 2+ items; RPC deducts source stock |
| 19 | TransferReceivePage | /inventory/transfers/{id}/receive | Form: receive items + qty per item → receive | inventory:update | transfersProvider.notifier.receive | Receive partial or full transfer; RPC credits dest warehouse |
| 20 | CountsPage | /inventory/counts | List + progress bar + variance indicator → open count session | inventory:update | countsProvider | Start count session; open detail page |
| 21 | CountSessionPage | /inventory/counts/{countId} | Form: items scan/edit qty + auto-save + complete dialog | inventory:approve | countsProvider.notifier.recordItem / complete | Scan 5 items; quantities auto-save; complete count |
| 22 | ImeiLookupPage | /inventory/imei | Search query / barcode scan / load-all → product detail | inventory:read | imeiProvider | Scan IMEI; find product by serial number |
| 23 | LabelPrintPage | /inventory/labels | Qty picker + template selector → print PDF | inventory:read | LabelPdfService.generate / Printing.layoutPdf | Select 10 labels + template → PDF renders |
| 24 | ImportProductsPage | /inventory/import | Pick CSV → map columns → preview table → bulk import | inventory:create | productsProvider.notifier.bulkImport | Upload CSV; preview 100 rows; import → DB |

---

## Test Case Summary

| Category | Count |
|----------|-------|
| **P0-MONEY** (GL posting, stock movement) | 6 |
| **P1-DATA** (product/stock/warehouse create/update) | 12 |
| **P2-READ** (list, filter, search, detail) | 5 |
| **P3-NAV** (navigation, routing) | 1 |

---

## Critical Paths (Priority Testing)

1. **Stock Movement → GL Posting** (P0-MONEY): StockMovementFormPage → RPC posts to GL. Test: qty, cost, account resolved correctly.
2. **Transfer Receive** (P0-MONEY): TransferReceivePage → debit source, credit dest warehouse. Test: qty accuracy, both warehouses updated.
3. **Adjustment Create** (P0-MONEY): AdjustmentFormPage → RPC posts stock move + GL. Test: both ledgers updated.
4. **Count Complete** (P1-DATA): CountSessionPage → final count closes; variance calculated. Test: variance correct; stock revalued.
5. **Product Import** (P1-DATA): ImportProductsPage → bulk import creates 100+ rows. Test: all rows inserted; duplicates rejected.

---

## Gaps & Anomalies

- StockMovementFormPage linked to detail via `/inventory/stock/{productId}` but no direct route in router
- TransferReceivePage partially-receive not enforced (user can enter qty < transfer qty) — may be intentional
- CountSessionPage auto-save can create orphan records if network fails mid-session
- ImportProductsPage lacks duplicate-detection UI feedback (silently skips dupe SKUs)

---

**Next:** Proceed to remaining 7 features: migration_import, notifications, purchasing, repair, reporting, sales, settings (51 pages total, abbreviated format).
