# INVENTORY FEATURE AUDIT — Lumina POS

Date: 2026-06-14 | Read-only. No code changes.

---

## 1. DEPENDENCY & PLATFORM SNAPSHOT

### pubspec.yaml — dependencies

| Package | Version | Notes |
|---|---|---|
| `flutter` | sdk | |
| `cupertino_icons` | ^1.0.8 | listed in known issues as unused |
| `supabase_flutter` | ^2.14.1 | |
| `flutter_riverpod` | ^3.3.1 | |
| `go_router` | ^17.3.0 | |
| `pinput` | ^6.0.2 | OTP fields |
| `window_manager` | ^0.5.1 | platform-guarded in main.dart |
| `flutter_secure_storage` | ^10.3.1 | PIN, branch selection, device fingerprint |
| `local_auth` | ^3.0.1 | biometric (Face ID / fingerprint) |
| `crypto` | ^3.0.7 | SHA-256 for PIN, device fingerprint |
| `device_info_plus` | ^13.1.0 | device registration |
| `qr_flutter` | ^4.1.0 | TOTP MFA QR code rendering only |

### dev_dependencies

| Package | Version |
|---|---|
| `flutter_test` | sdk |
| `flutter_lints` | ^6.0.0 |

### SDK versions

```
Flutter 3.38.9 • channel stable
Dart 3.10.8
```

### Target platforms (folders present)

| Platform | Folder exists | Platform guard in main.dart |
|---|---|---|
| iOS | `ios/` | No guard needed (no platform-specific iOS init) |
| Android | `android/` | No guard needed |
| macOS | `macos/` | `windowManager` guard: `!kIsWeb && (macOS\|windows\|linux)` |
| Windows | `windows/` | `windowManager` guard |
| Web | `web/` | Guarded out: `!kIsWeb` |

All five platform folders exist (`ios/`, `android/`, `macos/`, `windows/`, `web/`). The `main.dart` guard `lib/main.dart:12-18` gates `window_manager` for desktop only.

### Packages relevant to scoped features

| Feature | Package | Status |
|---|---|---|
| Camera | NOT PRESENT | No camera package in pubspec |
| Barcode/QR scanning | NOT PRESENT | No barcode scanner package; `qr_flutter` is QR rendering only (MFA enroll) |
| Speech/voice | NOT PRESENT | No speech or voice package |
| Permissions (camera/mic) | NOT PRESENT | No `permission_handler` |
| File picking | NOT PRESENT | No `file_picker` |
| Printing | NOT PRESENT | No `printing` or `pdf` package |
| PDF generation | NOT PRESENT | |
| CSV/Excel | NOT PRESENT | No CSV/Excel import or export anywhere in app |

---

## 2. INVENTORY FEATURE FOLDER TREE

### Full tree: `lib/features/inventory/`

```
domain/
  entities/
    adjustment_reason.dart         — enum AdjustmentReason (4 values)
    barcode_template.dart          — class BarcodeTemplate (id, tenantId, name, format, widthMm, heightMm, layout, isDefault)
    brand.dart                     — class Brand
    category.dart                  — class Category
    imei_record.dart               — class ImeiRecord
    imei_status.dart               — enum ImeiStatus (7 values)
    pricing_tier.dart              — class PricingTier
    product.dart                   — class Product + ProductType + ProductStatus enums
    product_image.dart             — class ProductImage
    product_variant.dart           — class ProductVariant (has barcode field)
    stock_adjustment.dart          — class StockAdjustment
    stock_balance.dart             — class StockBalance
    stock_count.dart               — class StockCount
    stock_count_item.dart          — class StockCountItem
    stock_count_status.dart        — enum StockCountStatus (6 values)
    stock_ledger_entry.dart        — class StockLedgerEntry
    stock_level.dart               — class StockLevel (joined view: product name, sku, on-hand, reserved, in-transit, available, isLowStock)
    stock_movement_type.dart       — enum StockMovementType (8 values)
    stock_transfer.dart            — class StockTransfer
    stock_transfer_item.dart       — class StockTransferItem
    stock_transfer_status.dart     — enum StockTransferStatus (5 values)
    warehouse.dart                 — class Warehouse
  failures/
    inventory_failure.dart         — sealed class InventoryFailure + 10 variant subclasses
  repositories/
    inventory_repository.dart      — abstract class InventoryRepository (156 lines, 55 method signatures)
  usecases/
    load_categories.dart           delete_category.dart          save_category.dart
    load_brands.dart               delete_brand.dart             save_brand.dart
    load_products.dart             get_product.dart              search_products.dart
    save_product.dart              delete_product.dart
    load_variants.dart             save_variant.dart             delete_variant.dart
    load_images.dart               save_image.dart               set_primary_image.dart
    delete_image.dart
    load_pricing_tiers.dart        save_pricing_tier.dart        delete_pricing_tier.dart
    load_barcode_templates.dart    save_barcode_template.dart
    load_warehouses.dart           create_warehouse.dart         update_warehouse.dart
    delete_warehouse.dart          set_default_warehouse.dart    ensure_default_warehouse.dart
    load_stock_balances.dart       load_product_ledger.dart      post_stock_movement.dart
    load_stock_levels.dart
    load_adjustments.dart          create_adjustment.dart        approve_adjustment.dart
    load_transfers.dart            load_transfer_items.dart      create_transfer.dart
    dispatch_transfer.dart         receive_transfer.dart         cancel_transfer.dart
    load_counts.dart               load_count_items.dart         open_count.dart
    record_count_item.dart         complete_count.dart
    load_imei.dart                 register_imei.dart
    load_inventory_settings.dart   update_approval_threshold.dart
data/
  datasources/
    inventory_remote_datasource.dart  — 594 lines, ~70 Supabase methods
  repositories/
    inventory_repository_impl.dart    — 800 lines, 55 method impls + _mapError
  models/
    category_model.dart            brand_model.dart              product_model.dart
    product_variant_model.dart     product_image_model.dart      pricing_tier_model.dart
    barcode_template_model.dart    warehouse_model.dart          stock_balance_model.dart
    stock_ledger_entry_model.dart  stock_level_model.dart        stock_adjustment_model.dart
    stock_transfer_model.dart      stock_transfer_item_model.dart
    stock_count_model.dart         stock_count_item_model.dart   imei_record_model.dart
presentation/
  controllers/
    barcode_templates_controller.dart   — AsyncNotifier<List<BarcodeTemplate>>
    brands_controller.dart              — AsyncNotifier<List<Brand>>
    categories_controller.dart          — AsyncNotifier<List<Category>>
    products_controller.dart            — AsyncNotifier<List<Product>> — load() + search(q)
    product_edit_controller.dart        — Notifier<AsyncValue<Product?>> — loadForEdit, saveProduct, sub-resources
    warehouses_controller.dart          — AsyncNotifier<List<Warehouse>>
    stock_levels_controller.dart        — AsyncNotifier<List<StockLevel>>
    adjustments_controller.dart         — AsyncNotifier<List<StockAdjustment>>
    transfers_controller.dart           — AsyncNotifier<List<StockTransfer>>
    counts_controller.dart              — AsyncNotifier<List<StockCount>>
    imei_controller.dart                — AsyncNotifier<List<ImeiRecord>>
  pages/
    inventory_hub_page.dart         — hub: 10 tiles in 2 sections
    products_page.dart              — list with search (300ms debounce) + category/status filter chips
    product_form_page.dart          — create/edit with variants/images/pricing sub-sections
    barcode_templates_page.dart     — template list
    barcode_template_form_page.dart — template create/edit
    categories_page.dart            — category list
    category_form_page.dart         — category create/edit
    brands_page.dart                — brand list
    brand_form_page.dart            — brand create/edit
    warehouses_page.dart            — warehouse list
    warehouse_form_page.dart        — warehouse create/edit
    stock_levels_page.dart          — stock levels list with search + low-stock toggle + warehouse filter
    product_stock_detail_page.dart  — single-product stock detail + ledger
    stock_movement_form_page.dart   — opening balance form
    adjustments_page.dart           — adjustments list
    adjustment_form_page.dart       — adjustment create
    transfers_page.dart             — transfers list
    transfer_form_page.dart         — transfer create
    transfer_receive_page.dart      — transfer receive
    counts_page.dart                — counts list
    count_session_page.dart         — count session (record items + complete)
    imei_lookup_page.dart           — IMEI lookup (local client-side filter)
```

### Core design tokens: `lib/core/design/`

| File | Contents |
|---|---|
| `app_colors.dart` | AppColors static class (accent #007AFF, background, textPrimary, textMuted, textHint, fieldFill, separator, success, warning, destructive, etc.) |
| `app_typography.dart` | AppTypography static class (largeTitle, title1, title2, headline, callout, subhead, body, footnote, caption, fieldLabel, fieldHint) |
| `app_spacing.dart` | AppSpacing static class (xs, sm, md, base, lg, xl, xxl, screenPadding, fieldGap) |
| `app_radius.dart` | AppRadius static class (field, card, chip) |
| `app_shadows.dart` | AppShadows static class |
| `app_motion.dart` | AppMotion static class |
| `app_theme.dart` | AppTheme.light (uses AppColors, AppTypography) |

### Shared design widgets: `lib/core/design/widgets/`

- `app_button.dart` — AppButton (label, variant: filled/tinted/plain, loading, fullWidth default false)
- `app_text_field.dart` — AppTextField (controller, label, prefixIcon, hint, keyboardType, obscureText)
- `app_card.dart` — AppCard (child wrapper with styling)
- `app_otp_field.dart` — AppOtpField (OAuth-style PIN entry)
- `app_inline_banner.dart` — AppInlineBanner (message, type: error/success/info)
- `responsive_form_scaffold.dart` — ResponsiveFormScaffold

### Core services: `lib/core/services/`

- `pin_service.dart` — PIN create/verify/salt via secure storage + Supabase sync
- `device_service.dart` — device fingerprint + upsert
- `mfa_service.dart` — TOTP enroll/challenge/verify
- `audit_service.dart` — audit log write + 1 retry
- `login_throttle_service.dart` — increment/reset failed login counts

### Core widgets: `lib/core/widgets/`

- `bottom_nav_shell.dart` — BottomNavShell (dashboard / inventory / sale / settings)
- `pin_pad.dart` — PinPad widget
- `permission_gate.dart` — PermissionGate

### Core infrastructure: `lib/core/`

- `env.dart` — Env.supabaseUrl + Env.supabaseAnonKey (hardcoded strings)
- `supabase.dart` — `final supabase = Supabase.instance.client;`

---

## 3. SEARCH PATHS (for barcode + voice to hook into)

### 3.1 Products search

**Datasource** — `lib/features/inventory/data/datasources/inventory_remote_datasource.dart:123-133`
```dart
Future<List<Map<String, dynamic>>> searchProducts(String q) async {
  final trimmed = q.trim();
  if (trimmed.isEmpty) return loadProducts();

  final list = await _client
      .from('products')
      .select(_productCols)
      .or('name.ilike.*$trimmed*,sku.ilike.*$trimmed*,barcode.ilike.$trimmed')
      .order('created_at', ascending: false);
  return list;
}
```
Matches: `name` (ILIKE substring), `sku` (ILIKE substring), `barcode` (ILIKE exact prefix). Barcode is a nullable text column. Uses `_productCols` constant at line 106.

**Use case** — `lib/features/inventory/domain/usecases/search_products.dart:7-14`
```dart
Future<(List<Product>, InventoryFailure?)> call(String q) async {
  return _repo.searchProducts(q);
}
```

**Controller** — `lib/features/inventory/presentation/controllers/products_controller.dart:39-51`
```dart
Future<void> search(String q) async {
  if (q.trim().isEmpty) { ref.invalidateSelf(); return; }
  state = const AsyncValue.loading();
  state = await AsyncValue.guard(() async {
    final (results, failure) =
        await ref.read(searchProductsUseCaseProvider).call(q.trim());
    if (failure != null) throw failure;
    return results;
  });
}
```

**Page** — `lib/features/inventory/presentation/pages/products_page.dart:47-55`
- `AppTextField` with hint "Name, SKU, or barcode" (line 107)
- 300ms debounce via `_onSearchTextChanged` (line 50)
- Results rendered as `ListView.builder` of `_ProductCard` widgets (lines 195-207)
- `_ProductCard` shows name, SKU, barcode, category, price, status chip

### 3.2 IMEI lookup

**Datasource** — `lib/features/inventory/data/datasources/inventory_remote_datasource.dart:540-548`
```dart
Future<List<Map<String, dynamic>>> loadImei({String? productId, String? status}) async {
  var query = _client.from('imei_records').select(_imeiCols);
  if (productId != null) query = query.eq('product_id', productId);
  if (status != null) query = query.eq('status', status);
  return query.order('created_at', ascending: false);
}
```

**Search logic** is client-side only — `lib/features/inventory/presentation/pages/imei_lookup_page.dart:32-43`
```dart
Future<void> _search() async {
  final q = _searchController.text.trim();
  if (q.isEmpty) return;
  setState(() => _searching = true);
  await ref.read(imeiProvider.notifier).load();
  final all = ref.read(imeiProvider).value ?? <ImeiRecord>[];
  setState(() {
    _results = all.where((r) => r.imei.toLowerCase().contains(q.toLowerCase())).toList();
    _searching = false;
  });
}
```
Loads all IMEI records, then filters client-side by `.imei.toLowerCase().contains(q)`. NO server-side search on IMEI.

### 3.3 Stock levels search

**Datasource** — `lib/features/inventory/data/datasources/inventory_remote_datasource.dart:343-354`
- Loads from `stock_balance` joined with `products!inner(name, sku, reorder_point)` for branch/warehouse.

**Search logic** is client-side only — `lib/features/inventory/presentation/pages/stock_levels_page.dart:47-53,166-174`
- 300ms debounce on `_searchText` (line 49)
- Filters loaded `List<StockLevel>` by `productName.contains(_searchText)` or `productSku.contains(_searchText)` (lines 167-170)
- Additional toggle: `_lowStockOnly` filter via `level.isLowStock` (lines 172-174)
- NO server-side search endpoint for stock levels.

### 3.4 Where is barcode currently used?

| Location | Usage |
|---|---|
| `Product.barcode` (nullable String) | `lib/features/inventory/domain/entities/product.dart:11` |
| `ProductVariant.barcode` (nullable String) | `lib/features/inventory/domain/entities/product_variant.dart:6` |
| Product form barcode field | `lib/features/inventory/presentation/pages/product_form_page.dart:320` — `AppTextField(label: 'Barcode', prefixIcon: Icons.barcode_reader, hint: 'Optional')` |
| Variant dialog barcode field | `lib/features/inventory/presentation/pages/product_form_page.dart:462` — variant barcode input |
| Search includes barcode | datasource `searchProducts` (line 130) matches `barcode.ilike` |
| Product card shows barcode | `lib/features/inventory/presentation/pages/products_page.dart:454-456` — renders barcode in subtitle |
| DuplicateSkuFailure message | `lib/features/inventory/domain/failures/inventory_failure.dart:12` — "A product with this SKU or barcode already exists." |
| `_mapError` detects barcode conflict | `lib/features/inventory/data/repositories/inventory_repository_impl.dart:58` — `if (msg.contains('barcode'))` |
| Barcode Templates feature | Full CRUD for label templates (name, format, width, height, layout JSON, isDefault) — see Section 8 |

### Is there ANY camera/scan code today?

**NO.** No camera package, no barcode scanner package, no `MobileScanner`, no platform channel for camera. Zero camera or scanning code anywhere in the app. The `Icons.barcode_reader` icon on the product form barcode field is purely decorative.

---

## 4. NAVIGATION & ENTRY POINTS

### 4.1 Inventory routes from router.dart

All inventory routes defined in `lib/router.dart:192-322`:

| Route | Page | Type |
|---|---|---|
| `/inventory/categories` | CategoriesPage | list |
| `/inventory/categories/create` | CategoryFormPage | form |
| `/inventory/categories/:categoryId` | CategoryFormPage(categoryId:) | form (edit) |
| `/inventory/brands` | BrandsPage | list |
| `/inventory/brands/create` | BrandFormPage | form |
| `/inventory/brands/:brandId` | BrandFormPage(brandId:) | form (edit) |
| `/inventory/products` | ProductsPage | list |
| `/inventory/products/create` | ProductFormPage | form |
| `/inventory/products/:productId` | ProductFormPage(productId:) | form (edit) |
| `/inventory/barcode-templates` | BarcodeTemplatesPage | list |
| `/inventory/barcode-templates/create` | BarcodeTemplateFormPage | form |
| `/inventory/barcode-templates/:templateId` | BarcodeTemplateFormPage(templateId:) | form (edit) |
| `/inventory/warehouses` | WarehousesPage | list |
| `/inventory/warehouses/create` | WarehouseFormPage | form |
| `/inventory/warehouses/:warehouseId` | WarehouseFormPage(warehouseId:) | form (edit) |
| `/inventory/stock` | StockLevelsPage | list |
| `/inventory/stock/movement` | StockMovementFormPage(productId:) | form |
| `/inventory/stock/:productId` | ProductStockDetailPage(productId:) | detail |
| `/inventory/adjustments` | AdjustmentsPage | list |
| `/inventory/adjustments/create` | AdjustmentFormPage | form |
| `/inventory/transfers` | TransfersPage | list |
| `/inventory/transfers/create` | TransferFormPage | form |
| `/inventory/transfers/:transferId/receive` | TransferReceivePage(transferId:) | form |
| `/inventory/counts` | CountsPage | list |
| `/inventory/counts/:countId` | CountSessionPage(countId:) | detail/action |
| `/inventory/imei` | ImeiLookupPage | lookup |

### 4.2 Inventory hub page tile structure

`lib/features/inventory/presentation/pages/inventory_hub_page.dart:12-101`

Two sections in a `SingleChildScrollView`:

**Section 1 — Products (no section label):**

1. Products — "Browse, search, and manage products" → `/inventory/products`
2. Barcode Templates — "Label layouts for printing" → `/inventory/barcode-templates`
3. Categories — "Organize products by category" → `/inventory/categories`
4. Brands — "Manage product brands" → `/inventory/brands`

**Section 2 — Stock (labeled "STOCK"):**

5. Warehouses — "Manage stock locations per branch" → `/inventory/warehouses`
6. Stock Levels — "View balances by product and location" → `/inventory/stock`
7. Adjustments — "Damage, theft, write-offs, and recounts" → `/inventory/adjustments`
8. Transfers — "Move stock between branches" → `/inventory/transfers`
9. Stock Counts — "Physical inventory audits" → `/inventory/counts`
10. IMEI Lookup — "Search and track serialized items" → `/inventory/imei`

Each tile is `_HubRow` (icon, title, subtitle, `context.push(path)` on tap).

### 4.3 Sub-screen navigation pattern

All sub-screens use `context.push()` (not `context.go()`), preserving the StatefulShellRoute bottom nav. Forms navigate back via `Navigator.of(context).pop()`. Forms do NOT return results through pop — they invalidate the list provider (`ref.invalidate(productsProvider)` etc.) and the list page re-renders from the controller's refreshed state.

- List → Form: `context.push('/inventory/products/create')`
- Form → List: `Navigator.of(context).pop()` + `ref.invalidate(productsProvider)` before pop
- List item → Edit form: `context.push('/inventory/products/${product.id}')` (inkwell onTap)

---

## 5. PERMISSIONS & ROLE GATING

### 5.1 PermissionGate signature

`lib/core/widgets/permission_gate.dart:7-32`
```dart
class PermissionGate extends ConsumerWidget {
  const PermissionGate({
    required this.module,
    required this.action,
    required this.child,
    this.fallback,    // default: SizedBox.shrink()
  });
  final String module;
  final String action;
  final Widget child;
  final Widget? fallback;
}
```
Checks `permissionMatrixProvider` (AsyncValue<Set<String>>) for key `'$module:$action'`. Renders `child` if present, `fallback` (or `SizedBox.shrink()`) otherwise.

### 5.2 Inventory module:action strings used in UI

From grep of all `module: 'inventory'` usages:

| Action | Where used |
|---|---|
| `create` | ProductsPage (+), CategoriesPage (+), BrandsPage (+), WarehousesPage (+), BarcodeTemplatesPage (+), CountsPage (Open Count), TransfersPage (Create), AdjustmentsPage (Create), ProductFormPage (Save button) |
| `update` | ProductFormPage edit (Save button), WarehousesPage edit, CategoriesPage edit, BrandsPage edit |
| `delete` | ProductFormPage edit (trash icon), WarehousesPage, CategoriesPage, BrandsPage |
| `approve` | AdjustmentsPage (Approve button), CountsPage (Complete) |
| `read` | NOT explicitly gated in UI (all inventory pages load data via controllers; RLS enforces `inventory:read` server-side on SELECT) |

Additional DB-side RPC gates (not visible in UI but enforced in SECURITY DEFINER RPCs):
- `inventory:create` — `create_stock_adjustment`, `open_stock_count`
- `inventory:update` — `post_stock_movement`, `dispatch/receive/cancel/transfer`, `record_count_item`, `complete_stock_count`, `set_default_warehouse`, `updateApprovalThreshold`
- `inventory:approve` — `approve_stock_adjustment`
- `inventory:delete` — `soft_delete_*` RPCs, `delete_warehouse`

### 5.3 Permission matrix per role (from seed SQL)

Seed: `supabase/migrations/20260609000002_auth_full_schema.sql:188-204`

**ADMIN** — full matrix on `inventory`:
`read, create, update, delete, approve, export` — branch_scope `ALL`, granted `true`

**CASHIER** — single permission on `inventory`:
`read` — branch_scope `OWN_BRANCH`, granted `true`

CASHIER cannot create, update, delete, or approve any inventory data. They can only view (read).

---

## 6. DATA-LAYER CONVENTIONS

### 6.1 Repository return style

Every method returns a record `(value, Failure?)`. Success = value populated, failure = null. Failure = failure non-null, value = sentinel.

Example from `lib/features/inventory/data/repositories/inventory_repository_impl.dart:79-87`:
```dart
Future<(List<Category>, InventoryFailure?)> loadCategories() async {
  try {
    final rows = await _ds.loadCategories();
    return (rows.map(CategoryModel.fromJson).toList(), null);
  } catch (e) {
    return (<Category>[], _mapError(e));
  }
}
```

### 6.2 InventoryFailure sealed type

`lib/features/inventory/domain/failures/inventory_failure.dart:1-56`

```dart
sealed class InventoryFailure { String get message; }

class NotFoundFailure             → 'The requested item was not found.'
class DuplicateSkuFailure         → 'A product with this SKU or barcode already exists.'
class PermissionDeniedFailure     → 'You do not have permission to perform this action.'
class NetworkFailure              → 'Network error. Please check your connection.'
class InsufficientStockFailure    → 'Insufficient stock to complete this movement.'
class WarehouseHasStockFailure    → 'Cannot delete a warehouse that still has stock.'
class DuplicateImeiFailure        → 'This IMEI is already registered.'
class ApprovalRequiredFailure     → 'This adjustment requires approval before posting.'
class InvalidTransitionFailure    → 'This status transition is not allowed.'
class UnknownFailure(String)      → details string
```

10 subclasses + base `sealed class InventoryFailure`.

### 6.3 Remote datasource pattern

`lib/features/inventory/data/datasources/inventory_remote_datasource.dart:1-13`
- Provider returns `InventoryRemoteDataSource(supabase)` — receives `SupabaseClient` in constructor
- Caches tenant ID after first lookup via `_tenantId()` (line 17-24)
- Accesses current user via `_client.auth.currentUser?.id` (line 34)

**Standard query:**
```dart
// line 38-43
Future<List<Map<String, dynamic>>> loadCategories() async {
  return _client.from('categories').select('id, tenant_id, name, slug, ...').order('sort_order');
}
```

**RPC call pattern:**
```dart
// line 370-383
Future<Map<String, dynamic>> postStockMovement({...}) async {
  final result = await _client.rpc('post_stock_movement', params: {
    'p_branch_id': branchId,
    'p_warehouse_id': warehouseId,
    ...
  });
  return result as Map<String, dynamic>;
}
```
RPC results are cast as `Map<String, dynamic>` (single row) — NOT List. This was a previously fixed bug.

### 6.4 AsyncNotifier controller pattern

`lib/features/inventory/presentation/controllers/barcode_templates_controller.dart:7-34`

```dart
final barcodeTemplatesProvider =
    AsyncNotifierProvider<BarcodeTemplatesController, List<BarcodeTemplate>>(
  BarcodeTemplatesController.new,
);

class BarcodeTemplatesController extends AsyncNotifier<List<BarcodeTemplate>> {
  @override
  Future<List<BarcodeTemplate>> build() async {
    final (templates, failure) = await ref.read(loadBarcodeTemplatesUseCaseProvider).call();
    if (failure != null) throw failure;
    return templates;
  }

  void refresh() => ref.invalidateSelf();

  Future<InventoryFailure?> save({required Map<String, dynamic> data, String? id}) async {
    final (_, failure) = await ref.read(saveBarcodeTemplateUseCaseProvider).call(data: data, id: id);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }
}
```

Pattern:
- `build()` loads initial data via use case, throws failure on error
- Mutations return `InventoryFailure?` (null = success), invalidate self on success
- `refresh()` wraps `ref.invalidateSelf()` for manual reload

### 6.5 Edit-form seeding pattern (post product-form fix)

`lib/features/inventory/presentation/controllers/product_edit_controller.dart:22-65`

Controller is a `Notifier<AsyncValue<Product?>>` (NOT AsyncNotifier), build returns `AsyncValue.data(null)`. The form:

1. Calls `loadForEdit(id)` which sets `editingId`, sets state to loading, fetches product, sets state to data
2. Loads sub-resources (variants, images, pricing tiers) concurrently
3. Page watches via `ref.listen<AsyncValue<Product?>>(productEditProvider, ...)` with a `_didSeed` guard (line 218-223 of product_form_page.dart)
4. When `p != null && !_didSeed`, calls `_loadExisting(p)` to populate all TextEditingControllers

**Before this fix**: `didChangeDependencies` was used for seeding — caused double-population. Now uses reactive `ref.listen` + guard flag.

---

## 7. DEVICE/INPUT CAPABILITIES

### 7.1 iOS Info.plist permission entries

`ios/Runner/Info.plist` — Only one custom permission entry:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to unlock Lumina POS.</string>
```
**No camera, no microphone, no photo library** permissions declared.

### 7.2 Android manifest permission entries

`android/app/src/main/AndroidManifest.xml` — **No custom permissions at all.** Only default Flutter entries (INTERNET is granted automatically via the Flutter embedding). No `<uses-permission>` tags for camera, microphone, or storage.

### 7.3 Platform channels / native code

**None.** Zero `MethodChannel`, `EventChannel`, `FederatedPlugin`, or custom platform-specific code anywhere in the Dart source tree.

### 7.4 Minimum OS versions

| Platform | Min Version |
|---|---|
| iOS | 13.0 (`IPHONEOS_DEPLOYMENT_TARGET = 13.0` in project.pbxproj:458,587,638) |
| Android | `flutter.minSdkVersion` (resolved by Flutter Gradle Plugin, typically 21 for Flutter 3.38) — `minSdk = flutter.minSdkVersion` in `android/app/build.gradle.kts:27` |

---

## 8. WHAT'S WIRED vs STUBBED

### 8.1 Barcode Templates — CRUD only, no label generation/printing

The barcode templates feature at `lib/features/inventory/presentation/pages/barcode_templates_page.dart` and `barcode_template_form_page.dart` is **pure template CRUD**:

- **List page**: renders saved templates as `_TemplateCard` showing name, format (CODE128/EAN13/QR), dimensions, "Default" chip
- **Form page**: name, format dropdown, width/height (mm), layout JSON, "Default" toggle
- **Entity** (`barcode_template.dart:1-21`): id, tenantId, name, format, widthMm, heightMm, layout (Map<String,dynamic>), isDefault
- **Datasource**: standard CRUD on `barcode_templates` table — `load`, `create`, `update` (no delete in datasource)

**Tapping through it:**
1. Hub → Barcode Templates → list of templates
2. Create (+) → form (name, format, dimensions, layout) → save → pops back to list
3. Tap a template → edit form → update → pops back
4. That's it. No "Print", no "Generate", no PDF/Image output.

**What's missing for label printing:**
- No `printing` package, no `pdf` package
- No barcode image generation library (the `qr_flutter` package renders QR codes but is used only for TOTP MFA, NOT for inventory labels)
- No "Generate Label" or "Print" button anywhere
- The hub tile subtitle says "Label layouts for printing" but the code stops at template definition

### 8.2 "Coming Soon" / TODOs in inventory feature

Inventory feature itself has **zero TODO/FIXME/stub markers**.

The only "Coming Soon" in the app is the **Sales tab** — `lib/features/auth/presentation/pages/sale_page.dart:28` — a placeholder showing "Coming soon" behind a `shopping_cart_outlined` icon.

### 8.3 CSV/Excel import/export

**NOT PRESENT** — No CSV, Excel, or bulk import/export anywhere in the app. Zero occurrences of `file_picker`, `csv`, `excel`, `xls`, or `export` in the Dart source tree. The permission matrix does seed an `export` action for ADMIN, but no UI or backend implements it.

---

## SUMMARY — Scoping Checklist

| Feature | Status | What exists |
|---|---|---|
| **Barcode scanning** | NOT PRESENT | No camera/scanner package, no permissions, no code. Hook point: `searchProducts(q)` datasource method (line 123-133) or a new barcode-only lookup endpoint. |
| **Voice search** | NOT PRESENT | No speech/voice package. Hook point: inject results into `ProductsController.search(q)` or create new `voiceSearchProducts` use case. |
| **Label printing** | Stub | Barcode templates CRUD exists. No generation/printing. Hook point: `BarcodeTemplate` entity + `barcode_templates` table + existing form/store. Need to add `printing` + `pdf` packages and a "Generate/Print" action. |
| **Bulk import** | NOT PRESENT | No file_picker, no CSV/Excel, no bulk endpoints. Hook point: `ProductsController` + `createProduct` in datasource for line-by-line insert, or new RPC for batch. |
| **Low-stock alerts** | Partial | `stock_levels_page.dart` has client-side `_lowStockOnly` toggle + `isLowStock` computed field on `StockLevel`. But no push notifications, no background service, no "alert threshold" settings UI. The `reorderPoint` field exists on `Product` entity. `inventory_settings` table has `adjustment_approval_threshold` but no `low_stock_threshold`. |
