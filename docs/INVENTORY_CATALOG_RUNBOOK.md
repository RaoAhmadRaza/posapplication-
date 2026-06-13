# INVENTORY CATALOG RUNBOOK

Slice A (Product Catalog) — complete. See PROJECT_STATE.md for current status.

## Files (all under lib/features/inventory/)

### Domain
- entities/: category, brand, product (+ProductType/ProductStatus enums), product_variant,
  product_image, pricing_tier, barcode_template
- failures/: inventory_failure.dart (sealed: NotFound, DuplicateSku, PermissionDenied,
  Network, Unknown)
- repositories/: inventory_repository.dart (abstract, 36 methods)
- usecases/: 23 files — Load/Save/Delete for every resource + SearchProducts, GetProduct,
  SetPrimaryImage

### Data
- datasources/: inventory_remote_datasource.dart (all Supabase calls, sluggen, tenant_id cache;
  soft-deletes use SECURITY DEFINER RPCs: soft_delete_brand, soft_delete_category,
  soft_delete_product — NOT direct UPDATE)
- models/: 7 models (fromJson/toJson, snake↔camel, decimal→double, enum↔string)
- repositories/: inventory_repository_impl.dart (PostgrestException→InventoryFailure)

### Presentation
- controllers/: categories, brands, products, product_edit, barcode_templates
- pages/: inventory_hub_page, categories_page, category_form_page, brands_page,
  brand_form_page, products_page, product_form_page, barcode_templates_page,
  barcode_template_form_page

### Routes (/inventory/*)
- /inventory → InventoryHubPage (shell)
- /inventory/categories, /create, /:categoryId
- /inventory/brands, /create, /:brandId
- /inventory/products, /create, /:productId
- /inventory/barcode-templates, /create, /:templateId

### Database
- Migrations: 20260611000001_product_catalog.sql, 20260611163739_product_sku_and_search.sql,
  20260611173542_fix_softdelete_rls.sql, 20260612000000_inventory_softdelete_rpcs.sql
- Tables: categories, brands, products, product_variants, product_images,
  product_pricing_tiers, barcode_templates
- RLS: auth_tenant_id() + auth_has_permission() for INSERT/UPDATE/DELETE
- Soft-delete: SECURITY DEFINER RPCs (soft_delete_brand/category/product) enforce tenant +
  inventory:delete permission; called via _client.rpc(...) in datasource

## Slice B — Stock Engine (next)
Tables: warehouses, stock_balance, stock_ledger (IMMUTABLE), imei_records, stock_transfers,
stock_transfer_items, stock_adjustments, stock_counts, stock_count_items.
See DATABASE_SCHEMA.md §3.7 for full schema reference.
