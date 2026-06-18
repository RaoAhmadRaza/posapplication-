# MIGRATION IMPORT AUDIT — Lumina POS

**Date:** 2026-06-16
**Status:** READ-ONLY DIAGNOSIS. No code, schema, or migration changes.
**Scope:** Pre-mapped CSV import for `branches`, `categories`, `brands`, `products`, `stock_balance` (each paired with an `OPENING_BALANCE` `stock_ledger` row), preserving original UUIDs, inserting in FK order.

---

## 1. LIVE TABLE SHAPES (the import targets)

All column data sourced from `information_schema.columns` via `supabase db query --linked` (live DB) or migration files where CLI auth failed. Branches data from migration `20260609000002_auth_full_schema.sql` (CLI auth failed for branches queries).

### 1.1 `branches`

Source: migration `supabase/migrations/20260609000002_auth_full_schema.sql:35-46` (live CLI failed with auth error; migration file is the canonical definition).

| column_name | data_type | is_nullable | column_default |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| tenant_id | uuid | NO | NULL |
| name | text | NO | NULL |
| code | text | NO | NULL |
| city | text | YES | NULL |
| country | text | YES | 'Pakistan' |
| currency | text | NO | 'PKR' |
| timezone | text | NO | 'Asia/Karachi' |
| is_active | boolean | NO | true |
| is_main | boolean | NO | false |
| created_at | timestamptz | NO | now() |

**UNIQUE index:** `uq_branches_tenant_code` on `(tenant_id, code)`
**CHECK constraints:** None beyond UNIQUE
**Note:** `branches` has NO `version`, `updated_at`, `deleted_at`, `created_by`, or `updated_by` columns — it's a simpler table than inventory tables.

### 1.2 `categories`

Live CLI query result.

| column_name | data_type | is_nullable | column_default |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| tenant_id | uuid | NO | NULL |
| name | varchar(255) | NO | NULL |
| slug | varchar(255) | NO | NULL |
| parent_id | uuid | YES | NULL |
| description | text | YES | NULL |
| image_url | varchar(500) | YES | NULL |
| sort_order | integer | NO | 0 |
| is_active | boolean | NO | true |
| created_at | timestamptz | NO | now() |
| updated_at | timestamptz | NO | now() |
| deleted_at | timestamptz | YES | NULL |
| version | integer | NO | 1 |
| created_by | uuid | YES | NULL |
| updated_by | uuid | YES | NULL |

**UNIQUE index:** `uq_categories_tenant_slug` on `(tenant_id, slug) WHERE deleted_at IS NULL`
**CHECK constraints:** None beyond UNIQUE
**FKs:** `parent_id → categories(id)`, `created_by/updated_by → users(id)`

### 1.3 `brands`

Live CLI query result.

| column_name | data_type | is_nullable | column_default |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| tenant_id | uuid | NO | NULL |
| name | varchar(255) | NO | NULL |
| slug | varchar(255) | NO | NULL |
| logo_url | varchar(500) | YES | NULL |
| description | text | YES | NULL |
| is_active | boolean | NO | true |
| created_at | timestamptz | NO | now() |
| updated_at | timestamptz | NO | now() |
| deleted_at | timestamptz | YES | NULL |
| version | integer | NO | 1 |
| created_by | uuid | YES | NULL |
| updated_by | uuid | YES | NULL |

**UNIQUE index:** `uq_brands_tenant_slug` on `(tenant_id, slug) WHERE deleted_at IS NULL`
**CHECK constraints:** None beyond UNIQUE.

### 1.4 `products`

Live CLI query result.

| column_name | data_type | is_nullable | column_default |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| tenant_id | uuid | NO | NULL |
| sku | varchar(100) | NO | NULL |
| name | varchar(500) | NO | NULL |
| description | text | YES | NULL |
| barcode | varchar(100) | YES | NULL |
| type | product_type_enum | NO | 'STANDARD' |
| category_id | uuid | YES | NULL |
| brand_id | uuid | YES | NULL |
| unit_of_measure | varchar(50) | NO | 'PCS' |
| cost_price | decimal(15,4) | NO | 0 |
| selling_price | decimal(15,4) | NO | 0 |
| min_selling_price | decimal(15,4) | YES | NULL |
| wholesale_price | decimal(15,4) | YES | NULL |
| tax_rate | decimal(5,2) | NO | 0 |
| tax_inclusive | boolean | NO | false |
| reorder_point | integer | NO | 0 |
| reorder_qty | integer | NO | 0 |
| weight | decimal(10,3) | YES | NULL |
| is_active | boolean | NO | true |
| status | product_status_enum | NO | 'ACTIVE' |
| image_url | varchar(500) | YES | NULL |
| tags | text[] | YES | NULL |
| custom_fields_json | jsonb | YES | '{}' |
| search_vector | tsvector | YES | NULL |
| created_at | timestamptz | NO | now() |
| updated_at | timestamptz | NO | now() |
| deleted_at | timestamptz | YES | NULL |
| version | integer | NO | 1 |
| created_by | uuid | YES | NULL |
| updated_by | uuid | YES | NULL |

**UNIQUE indexes:**
- `uq_products_tenant_sku` on `(tenant_id, sku) WHERE deleted_at IS NULL`
- `uq_products_tenant_barcode` on `(tenant_id, barcode) WHERE deleted_at IS NULL AND barcode IS NOT NULL`

**CHECK constraints:** None beyond UNIQUE. Type is `product_type_enum`: `('STANDARD','SERIALIZED','SERVICE','COMPOSITE')`. Status is `product_status_enum`: `('ACTIVE','INACTIVE','DISCONTINUED')`.

### 1.5 `stock_balance`

Live CLI query result.

| column_name | data_type | is_nullable | column_default |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| tenant_id | uuid | NO | NULL |
| branch_id | uuid | NO | NULL |
| warehouse_id | uuid | YES | NULL |
| product_id | uuid | NO | NULL |
| variant_id | uuid | YES | NULL |
| qty_on_hand | numeric | NO | 0 |
| qty_reserved | numeric | NO | 0 |
| qty_in_transit | numeric | NO | 0 |
| avg_cost | numeric | NO | 0 |
| last_stock_take | timestamptz | YES | NULL |
| reorder_point | integer | YES | NULL |
| last_updated | timestamptz | NO | now() |
| version | integer | NO | 1 |

**CHECK constraints:**
- `chk_stock_balance_on_hand CHECK (qty_on_hand >= 0)`
- `chk_stock_balance_reserved CHECK (qty_reserved >= 0)`
- `chk_stock_balance_transit CHECK (qty_in_transit >= 0)`

**UNIQUE indexes (split on `warehouse_id` nullability):**
- `uq_stock_balance_tenant_branch_product` — unique on `(tenant_id, branch_id, product_id, coalesce(variant_id,'00000000-...')) WHERE warehouse_id IS NULL`
- `uq_stock_balance_tenant_branch_wh_product` — unique on `(tenant_id, branch_id, warehouse_id, product_id, coalesce(variant_id,'00000000-...')) WHERE warehouse_id IS NOT NULL`

**FKs:** `tenant_id → tenants(id)`, `branch_id → branches(id)`, `warehouse_id → warehouses(id)`, `product_id → products(id)`, `variant_id → product_variants(id)`

**`warehouse_id` nullability:** YES — nullable. NULL means "branch default location" (see migration comment line 79).

### 1.6 `stock_ledger`

Live CLI query result.

| column_name | data_type | is_nullable | column_default |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| tenant_id | uuid | NO | NULL |
| product_id | uuid | NO | NULL |
| variant_id | uuid | YES | NULL |
| branch_id | uuid | NO | NULL |
| warehouse_id | uuid | YES | NULL |
| operation_type | stock_movement_type_enum | NO | NULL |
| qty_change | decimal(15,4) | NO | NULL |
| cost_per_unit | decimal(15,4) | NO | 0 |
| total_cost | decimal(15,4) | NO | 0 |
| balance_after | decimal(15,4) | NO | NULL |
| avg_cost_after | decimal(15,4) | NO | 0 |
| reference_id | uuid | NO | NULL |
| reference_type | varchar(50) | NO | NULL |
| imei_id | uuid | YES | NULL |
| batch_number | varchar(100) | YES | NULL |
| correlation_id | uuid | YES | NULL |
| notes | text | YES | NULL |
| created_at | timestamptz | NO | now() |
| created_by | uuid | YES | NULL |

**UNIQUE indexes:** None.
**CHECK constraints:** None beyond FK.
**FKs:** `tenant_id → tenants(id)`, `product_id → products(id)`, `variant_id → product_variants(id)`, `branch_id → branches(id)`, `warehouse_id → warehouses(id)`, `imei_id → imei_records(id)`

### 1.7 `warehouses`

Live CLI query result.

| column_name | data_type | is_nullable | column_default |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| tenant_id | uuid | NO | NULL |
| branch_id | uuid | NO | NULL |
| name | varchar(255) | NO | NULL |
| code | varchar(20) | NO | NULL |
| address | text | YES | NULL |
| capacity_notes | text | YES | NULL |
| is_active | boolean | NO | true |
| is_default | boolean | NO | false |
| created_at | timestamptz | NO | now() |
| updated_at | timestamptz | NO | now() |
| deleted_at | timestamptz | YES | NULL |
| version | integer | NO | 1 |
| created_by | uuid | YES | NULL |
| updated_by | uuid | YES | NULL |

**UNIQUE indexes:**
- `uq_warehouses_tenant_code` on `(tenant_id, code) WHERE deleted_at IS NULL`
- `uq_warehouses_one_default_per_branch` on `(branch_id) WHERE is_default AND deleted_at IS NULL`

### 1.8 `tenants`

Live CLI query result.

| column_name | data_type | is_nullable | column_default |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| name | text | NO | NULL |
| created_at | timestamptz | NO | now() |
| slug | text | YES | NULL |
| settings_json | jsonb | NO | '{}' |
| is_active | boolean | NO | true |

**UNIQUE indexes:** None declared in migrations. PK on `id`.
**CHECK constraints:** None.

### 1.9 `users`

Live CLI query result.

| column_name | data_type | is_nullable | column_default |
|---|---|---|---|
| id | uuid | NO | NULL (FK `auth.users(id)`) |
| tenant_id | uuid | YES | NULL |
| role_id | uuid | YES | NULL |
| full_name | text | YES | NULL |
| email | text | YES | NULL |
| status | text | NO | 'ACTIVE' |
| created_at | timestamptz | NO | now() |
| updated_at | timestamptz | NO | now() |
| phone | text | YES | NULL |
| avatar_url | text | YES | NULL |
| last_login_at | timestamptz | YES | NULL |
| failed_login_count | integer | NO | 0 |
| locked_until | timestamptz | YES | NULL |
| pin_hash | text | YES | NULL |

**UNIQUE indexes:** None beyond PK (PK is `id` = FK to `auth.users(id)`).
**CHECK constraints:** None.

### 1.10 `user_branch_assignments`

Live CLI query result.

| column_name | data_type | is_nullable | column_default |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| user_id | uuid | NO | NULL |
| branch_id | uuid | NO | NULL |
| is_default | boolean | NO | false |
| created_at | timestamptz | NO | now() |

**UNIQUE index:** `uq_user_branch` on `(user_id, branch_id)`
**CHECK constraints:** None.

### 1.11 `roles`

Live CLI query result.

| column_name | data_type | is_nullable | column_default |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| tenant_id | uuid | YES | NULL |
| name | text | NO | NULL |
| created_at | timestamptz | NO | now() |
| description | text | YES | NULL |
| is_system_role | boolean | NO | false |
| hierarchy_level | integer | NO | 99 |
| requires_mfa | boolean | NO | false |

**UNIQUE indexes:** None declared in migrations. PK on `id`.
**CHECK constraints:** None.

### 1.12 `permissions`

Live CLI query result.

| column_name | data_type | is_nullable | column_default |
|---|---|---|---|
| id | uuid | NO | gen_random_uuid() |
| role_id | uuid | NO | NULL |
| module | text | NO | NULL |
| action | text | NO | NULL |
| branch_scope | branch_scope_enum | NO | 'OWN_BRANCH' |
| granted | boolean | NO | false |
| created_at | timestamptz | NO | now() |

**UNIQUE index:** `uq_permissions_role_module_action` on `(role_id, module, action)`
**CHECK constraints:** None. `branch_scope` enum: `('ALL','OWN_BRANCH','ASSIGNED_BRANCHES')`.

---

## 2. PRODUCTS SPECIFICS

### 2.1 Column existence check

| CSV column asked | Exists in products? | Column name | Nullable? | Default |
|---|---|---|---|---|
| sku | YES | `sku` (varchar 100) | NO | NULL (filled by trigger) |
| barcode | YES | `barcode` (varchar 100) | YES | NULL |
| retail_price | NOT PRESENT | — | — | — |
| min_selling_price | YES | `min_selling_price` (decimal 15,4) | YES | NULL |
| wholesale_price | YES | `wholesale_price` (decimal 15,4) | YES | NULL |
| selling_price | YES | `selling_price` (decimal 15,4) | NO | 0 |
| cost_price | YES | `cost_price` (decimal 15,4) | NO | 0 |
| tax_rate | YES | `tax_rate` (decimal 5,2) | NO | 0 |
| reorder_point | YES | `reorder_point` (integer) | NO | 0 |
| status | YES | `status` (product_status_enum) | NO | 'ACTIVE' |
| type | YES | `type` (product_type_enum) | NO | 'STANDARD' |
| unit_of_measure | YES | `unit_of_measure` (varchar 50) | NO | 'PCS' |
| is_active | YES | `is_active` (boolean) | NO | true |
| slug | NOT PRESENT | — | — | — |
| search_vector | YES | `search_vector` (tsvector) | YES | NULL (computed by trigger) |
| created_by | YES | `created_by` (uuid) | YES | NULL |
| updated_by | YES | `updated_by` (uuid) | YES | NULL |
| deleted_at | YES | `deleted_at` (timestamptz) | YES | NULL |
| version | YES | `version` (integer) | NO | 1 |

**Key absences:** `retail_price` (NOT PRESENT — use `selling_price`), `slug` (NOT PRESENT on products — `sku` is the unique key).

### 2.2 SKU auto-generation trigger — explicit `sku` on insert IS RESPECTED

File: `supabase/migrations/20260611163739_product_sku_and_search.sql:50-69`

```sql
create or replace function public.trg_product_assign_sku()
returns trigger language plpgsql security definer set search_path = public as $$
begin
    if new.sku is null or new.sku = '' then
        new.sku := public.next_product_sku(new.tenant_id);
    end if;
    return new;
end;
$$;

drop trigger if exists trg_product_before_insert_sku on public.products;
create trigger trg_product_before_insert_sku
    before insert on public.products
    for each row
    execute function public.trg_product_assign_sku();
```

**Verdict:** The trigger ONLY auto-generates a PRD-000001–style SKU when `new.sku IS NULL OR new.sku = ''`. If the CSV supplies an explicit non-empty `sku`, the trigger **respects it and does not override**. This means the migration import CSV can carry original SKU values and they will be preserved.

The generator is `next_product_sku(p_tenant uuid)` (same file, lines 26-46) which produces `'PRD-' || lpad(v_num, 6, '0')` — atomically via UPDATE...RETURNING on `product_sku_sequences`.

### 2.3 Products search_vector BEFORE INSERT/UPDATE trigger

File: `supabase/migrations/20260611000001_product_catalog.sql:46-57` (function), lines 226-229 (trigger binding)

```sql
create or replace function public.fn_products_search_vector()
returns trigger language plpgsql as $$
begin
  new.search_vector :=
    setweight(to_tsvector('english', coalesce(new.name, '')),        'A') ||
    setweight(to_tsvector('english', coalesce(new.sku, '')),         'A') ||
    setweight(to_tsvector('english', coalesce(new.barcode, '')),     'B') ||
    setweight(to_tsvector('english', coalesce(new.description, '')), 'C') ||
    setweight(to_tsvector('english', coalesce((select name from public.brands     where id = new.brand_id),    '')), 'C') ||
    setweight(to_tsvector('english', coalesce((select name from public.categories where id = new.category_id), '')), 'C');
  return new;
end; $$;

-- Trigger fires BEFORE INSERT OR UPDATE OF name, sku, barcode, description, brand_id, category_id
create trigger trg_products_search_vector
  before insert or update of name, sku, barcode, description, brand_id, category_id
  on public.products for each row execute function public.fn_products_search_vector();
```

**Verdict:** This trigger auto-computes `search_vector` on every INSERT. The CSV does NOT need to supply `search_vector`. It will be populated from the other columns.

### 2.4 Products BEFORE UPDATE trigger (`fn_touch_row`)

File: `supabase/migrations/20260611000001_product_catalog.sql:215-217`

```sql
drop trigger if exists trg_products_touch on public.products;
create trigger trg_products_touch before update on public.products
  for each row execute function public.fn_touch_row();
```

`fn_touch_row()` (lines 29-35):
```sql
create or replace function public.fn_touch_row()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  new.version    := old.version + 1;
  return new;
end; $$;
```

This fires on UPDATE (not INSERT). Import INSERT is unaffected.

---

## 3. STOCK ENGINE HOOKS

### 3.1 `post_stock_movement` — exact signature

File: `supabase/migrations/20260613061924_stock_engine.sql:209-262`

```sql
create or replace function public.post_stock_movement(
  p_branch_id     uuid,
  p_warehouse_id  uuid,
  p_product_id    uuid,
  p_variant_id    uuid,
  p_operation_type stock_movement_type_enum,
  p_qty_change    numeric,
  p_cost_per_unit numeric default 0,
  p_reference_type text default 'OPENING',
  p_reference_id  uuid default null,
  p_notes         text default null
) returns public.stock_balance
language plpgsql security definer set search_path = public
```

**11 parameters.** All required except `p_warehouse_id`, `p_variant_id`, `p_reference_id`, `p_notes` which can be null.

**Logic (para):**
1. Derives `v_tenant := public.auth_tenant_id()` and `v_uid := auth.uid()`
2. Checks tenant non-null, permission `inventory:update`, branch assignment, non-zero qty, product exists in tenant, warehouse exists in branch
3. Inserts into `stock_ledger` — trigger `trg_apply_stock_ledger` (BEFORE INSERT) computes `balance_after`, `avg_cost_after`, `total_cost` on the NEW row and upserts `stock_balance`
4. Returns the updated `stock_balance` row

**Critical:** The function is SECURITY DEFINER — it sets `tenant_id` from the calling user's `auth_tenant_id()` (line 223: `v_tenant uuid := public.auth_tenant_id()`). All ledger rows receive this tenant. The CSV's original `tenant_id` is NOT used — the importer's own tenant is used.

### 3.2 `fn_apply_stock_ledger` — the balance-maintenance trigger

File: `supabase/migrations/20260613061924_stock_engine.sql:129-176`

```sql
create or replace function public.fn_apply_stock_ledger()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_bal   public.stock_balance;
  v_new   decimal(15,4);
  v_avg   decimal(15,4);
  v_wh_key uuid := coalesce(new.warehouse_id, '00000000-0000-0000-0000-000000000000'::uuid);
  v_var_key uuid := coalesce(new.variant_id, '00000000-0000-0000-0000-000000000000'::uuid);
begin
  select * into v_bal from public.stock_balance b
   where b.tenant_id = new.tenant_id and b.branch_id = new.branch_id
     and b.product_id = new.product_id
     and coalesce(b.warehouse_id,'00000000-...'::uuid) = v_wh_key
     and coalesce(b.variant_id, '00000000-...'::uuid)  = v_var_key
   for update;

  if not found then
    v_new := new.qty_change;
    if v_new < 0 then raise exception 'insufficient stock' using errcode = 'P0001'; end if;
    v_avg := case when new.qty_change > 0 then new.cost_per_unit else 0 end;
    insert into public.stock_balance
      (tenant_id, branch_id, warehouse_id, product_id, variant_id, qty_on_hand, avg_cost, last_updated)
    values (new.tenant_id, new.branch_id, new.warehouse_id, new.product_id, new.variant_id, v_new, v_avg, now())
    returning * into v_bal;
  else
    v_new := v_bal.qty_on_hand + new.qty_change;
    if v_new < 0 then raise exception 'insufficient stock' using errcode = 'P0001'; end if;
    v_avg := case
               when new.qty_change > 0 and new.cost_per_unit > 0
               then ((v_bal.qty_on_hand * v_bal.avg_cost) + (new.qty_change * new.cost_per_unit))
                    / nullif(v_bal.qty_on_hand + new.qty_change, 0)
               else v_bal.avg_cost
             end;
    update public.stock_balance
       set qty_on_hand = v_new, avg_cost = v_avg, last_updated = now(), version = version + 1
     where id = v_bal.id;
  end if;

  new.balance_after  := v_new;
  new.avg_cost_after := v_avg;
  new.total_cost     := new.qty_change * new.cost_per_unit;
  return new;
end; $$;

drop trigger if exists trg_apply_stock_ledger on public.stock_ledger;
create trigger trg_apply_stock_ledger
  before insert on public.stock_ledger
  for each row execute function public.fn_apply_stock_ledger();
```

**Key behaviors:**
- If no `stock_balance` row exists: creates one with `qty_on_hand = qty_change`, blocks negative.
- If balance exists: adds `qty_change` to existing on-hand, blocks negative (err `P0001`).
- Weighted-avg cost computed for positive-qty movements with `cost_per_unit > 0`.
- Stamps `balance_after`, `avg_cost_after`, `total_cost` back onto the NEW ledger row.

### 3.3 Stock ledger immutability trigger

File: `supabase/migrations/20260613061924_stock_engine.sql:115-123`

```sql
create or replace function public.fn_stock_ledger_immutable()
returns trigger language plpgsql as $$
begin
  raise exception 'stock_ledger is immutable (append-only); compensate with a new movement'
    using errcode = 'P0001';
end; $$;

create trigger trg_stock_ledger_immutable
  before update or delete on public.stock_ledger
  for each row execute function public.fn_stock_ledger_immutable();
```

**Any UPDATE/DELETE on `stock_ledger` raises `P0001`.** Only INSERT is permitted. Confirmed by migration line 200: `revoke insert, update, delete on public.stock_ledger from anon, authenticated;` — all writes must go through SECURITY DEFINER RPC.

### 3.4 `stock_balance` — warehouse_id nullability + indexes

**`warehouse_id`: YES, nullable.**
- NULL means "branch default location"
- The unique indexes split on this:
  - `uq_stock_balance_tenant_branch_product` — WHERE `warehouse_id IS NULL`
  - `uq_stock_balance_tenant_branch_wh_product` — WHERE `warehouse_id IS NOT NULL`

**Direct writes REVOKED** (line 206): `revoke insert, update, delete on public.stock_balance from anon, authenticated;` — confirmed live RLS policy list shows only `balance read` (SELECT). All writes must go through `post_stock_movement` (or a new SECURITY DEFINER RPC).

**Columns present:** `qty_reserved` (YES), `qty_in_transit` (YES), `avg_cost` (YES), `reorder_point` (YES, nullable), `last_updated` (YES), `version` (YES).

---

## 4. F4 BULK IMPORT — WHAT EXISTS TO REUSE

### 4.1 Packages

`pubspec.yaml:51-52`:
```yaml
file_picker: ^3.0.4
csv: ^8.0.0
```

### 4.2 Import page — file pick + CSV parse

File: `lib/features/inventory/presentation/pages/import_products_page.dart` (507 lines)

**File-pick + CSV parse** (lines 56-101):
```dart
final result = await FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: ['csv'],
);
final content = String.fromCharCodes(result.files.first.bytes ?? []);
final parsed = Csv().decode(content);
```

**Column-mapping UI** (lines 260-323):
- Reads CSV headers, auto-maps by lowercased substring match against `_targetFields`
- Per-column dropdown: select target field or "Ignore"
- Target fields: `['name', 'barcode', 'category_name', 'brand_name', 'cost_price', 'selling_price', 'unit_of_measure']`
- Preview table renders first 20 rows with per-field highlighting

**Payload builder** (lines 105-125):
```dart
List<Map<String, dynamic>> _buildPayload() {
    // Builds Map per row: {name, barcode, category_name, brand_name, cost_price, selling_price, unit_of_measure}
    // Skips rows where name is null
}
```

**Import call** (lines 135-169):
```dart
final result = await ref
    .read(productsProvider.notifier)
    .bulkImport(jsonEncode(payload));
```
Result parse: `{ok, failed, errors[{row, error}]}` returned as `Map<String, dynamic>?`.

### 4.3 Controller method

File: `lib/features/inventory/presentation/controllers/products_controller.dart:54-60`

```dart
Future<Map<String, dynamic>?> bulkImport(String jsonPayload) async {
    final (result, failure) =
        await ref.read(bulkImportProductsUseCaseProvider).call(jsonPayload);
    if (failure != null) return null;
    ref.invalidateSelf();
    return result;
}
```

**Path:** Controller → `BulkImportProducts` use case → `InventoryRepositoryImpl.bulkImportProducts()` → `InventoryRemoteDataSource.bulkImportProducts()` → RPC.

### 4.4 Datasource method

File: `lib/features/inventory/data/datasources/inventory_remote_datasource.dart:595-600`

```dart
Future<Map<String, dynamic>> bulkImportProducts(String jsonPayload) async {
    final result = await _client.rpc('bulk_import_products', params: {
      'p_rows': jsonPayload,
    });
    return Map<String, dynamic>.from(result as Map);
}
```

### 4.5 `bulk_import_products` RPC — full body

File: `supabase/migrations/20260616100723_bulk_import_products.sql:1-36`

```sql
create or replace function public.bulk_import_products(p_rows jsonb)
-- p_rows: [{name, barcode, category_name, brand_name, cost_price, selling_price, unit_of_measure}]
returns jsonb language plpgsql security definer set search_path = public as $$
declare v_tenant uuid := public.auth_tenant_id(); r jsonb; v_cat uuid; v_brand uuid;
        v_ok int := 0; v_fail int := 0; v_errors jsonb := '[]'::jsonb; v_i int := 0;
begin
  if v_tenant is null then raise exception 'no tenant' using errcode='42501'; end if;
  if not public.auth_has_permission('inventory','create') then raise exception 'permission denied' using errcode='42501'; end if;
  for r in select * from jsonb_array_elements(p_rows) loop
    v_i := v_i + 1;
    begin
      if coalesce(trim(r->>'name'),'') = '' then raise exception 'name required'; end if;
      v_cat := null; v_brand := null;
      if coalesce(r->>'category_name','') <> '' then
        select id into v_cat from public.categories where tenant_id=v_tenant and lower(name)=lower(r->>'category_name') and deleted_at is null limit 1;
      end if;
      if coalesce(r->>'brand_name','') <> '' then
        select id into v_brand from public.brands where tenant_id=v_tenant and lower(name)=lower(r->>'brand_name') and deleted_at is null limit 1;
      end if;
      insert into public.products (tenant_id, name, barcode, category_id, brand_id, unit_of_measure, cost_price, selling_price, created_by, updated_by)
      values (v_tenant, trim(r->>'name'), nullif(r->>'barcode',''), v_cat, v_brand,
              coalesce(nullif(r->>'unit_of_measure',''),'PCS'),
              coalesce((r->>'cost_price')::numeric,0), coalesce((r->>'selling_price')::numeric,0),
              auth.uid(), auth.uid());
      v_ok := v_ok + 1;
    exception when others then
      v_fail := v_fail + 1;
      v_errors := v_errors || jsonb_build_object('row', v_i, 'error', SQLERRM);
    end;
  end loop;
  return jsonb_build_object('ok', v_ok, 'failed', v_fail, 'errors', v_errors);
end; $$;
```

**Return shape:** `{ok: int, failed: int, errors: [{row: int, error: string}]}`

**Limitations of this RPC for the migration import:**
- Only inserts into `products` — does NOT handle `branches`, `categories`, `brands`, `stock_balance`, `stock_ledger`, `tenants`, `users`, etc.
- Does NOT support explicit UUIDs (the INSERT does not include `id` — DB auto-generates)
- Category/brand resolution is by name match, not pre-mapped UUID
- Tenant is forced to `auth_tenant_id()` (the calling user's tenant)
- PRODUCTS only — the migration import needs many more tables.

---

## 5. RLS / PERMISSIONS THAT WILL BLOCK INSERTS

All RLS policies confirmed via live `pg_policies` query. Source migrations cross-verified.

### 5.1 Direct insert grants table

| Table | INSERT policy? | INSERT WITH CHECK | Direct insert granted to authenticated? |
|---|---|---|---|
| `tenants` | NO | — | NO (only SELECT) |
| `roles` | NO | — | NO (only SELECT) |
| `users` | NO | — | NO (SELECT + UPDATE own only) |
| `user_branch_assignments` | NO | — | NO (only SELECT self) |
| `permissions` | NO | — | NO (only SELECT) |
| `branches` | YES (via ALL) | `tenant_id = auth_tenant_id() AND auth_role_name() = 'ADMIN'` | YES — but ONLY for ADMIN role |
| `categories` | YES | `tenant_id = auth_tenant_id() AND auth_has_permission('inventory','create')` | YES (authenticated, if permission matrix allows) |
| `brands` | YES | `tenant_id = auth_tenant_id() AND auth_has_permission('inventory','create')` | YES |
| `products` | YES | `tenant_id = auth_tenant_id() AND auth_has_permission('inventory','create')` | YES |
| `warehouses` | YES | `tenant_id = auth_tenant_id() AND auth_has_branch(branch_id) AND auth_has_permission('inventory','create')` | YES |
| `stock_balance` | NO | — | **REVOKED** (only `balance read` SELECT) |
| `stock_ledger` | NO | — | **REVOKED** (only `ledger read` SELECT) |

### 5.2 Revoked grants on stock tables (confirmed live)

From `supabase/migrations/20260613061924_stock_engine.sql:200,206`:
```sql
revoke insert, update, delete on public.stock_ledger from anon, authenticated;
revoke insert, update, delete on public.stock_balance from anon, authenticated;
```

**The migration importer CANNOT insert directly into `stock_balance` or `stock_ledger`.** It MUST use `post_stock_movement` (SECURITY DEFINER RPC) or create a new SECURITY DEFINER RPC.

### 5.3 Permission needed

For inventory tables (categories, brands, products, warehouses): `inventory:create` must be granted to the calling user's role.

For branches: `auth_role_name() = 'ADMIN'`.

**ADMIN role seeds (confirmed):** The Demo Store ADMIN role (id `00000000-0000-0000-0000-000000000011`) has all 36 permissions including `inventory:create` (see migration `20260609000002_auth_full_schema.sql:190-194`).

Business-owner ADMINs get the same full matrix via `handle_new_user()`.

### 5.4 Tables requiring SECURITY DEFINER RPC for migration import

These tables lack INSERT RLS policies and CANNOT be directly inserted by authenticated users:

| Table | Reason | Needs new RPC? |
|---|---|---|
| `tenants` | No INSERT policy | YES — `migrate_import_tenant(...)` |
| `roles` | No INSERT policy | YES — `migrate_import_role(...)` |
| `users` | No INSERT policy (profile row — PK references `auth.users(id)`, which must exist first) | YES — `migrate_import_user(...)` |
| `user_branch_assignments` | No INSERT policy | YES — `migrate_import_assignment(...)` |
| `permissions` | No INSERT policy | YES — `migrate_import_permission(...)` |
| `stock_balance` | REVOKED direct writes | YES — reuse `post_stock_movement` or new batch RPC |
| `stock_ledger` | REVOKED direct writes | YES — reuse `post_stock_movement` or new batch RPC |

**Tables that allow direct authenticated INSERT (with `inventory:create`):**
- `branches` (ADMIN only)
- `categories`
- `brands`
- `products`
- `warehouses`

---

## 6. TENANT/BRANCH CROSS-TENANT REALITY

### 6.1 How `auth_tenant_id()` works

File: `supabase/migrations/20260609000002_auth_full_schema.sql:136-139`

```sql
create or replace function public.auth_tenant_id()
returns uuid language sql stable security definer set search_path = public as $$
  select tenant_id from public.users where id = auth.uid();
$$;
```

It reads `tenant_id` from the calling user's profile row in `public.users`. ONE tenant per logged-in user.

### 6.2 RLS WITH CHECK impact on CSV tenant_id

Every RLS INSERT policy uses WITH CHECK `tenant_id = public.auth_tenant_id()`. This means:

**If the CSV carries `tenant_id = '6919b0a1-...'` (a DIFFERENT tenant from the logged-in user):**
- Direct INSERT into `branches`, `categories`, `brands`, `products`, `warehouses` will **REJECT** the row because the CSV's tenant_id != `auth_tenant_id()`.
- `post_stock_movement` also hardcodes `v_tenant := public.auth_tenant_id()` (line 223 of stock_engine migration) — no way to pass a different tenant.

**Options:**
1. **Rewrite tenant_id to the importer's tenant.** All CSV tenant_id values are replaced with the logged-in user's `tenant_id`. This is the simplest safe path — the importer migrates data INTO their own tenant. Pre-mapped UUIDs for cross-references still work since they're within-tenant.
2. **The importer logs in AS the target tenant.** If the CSV tenant_id = '6919b0a1-...' is a real tenant with its own auth users, a user from that tenant logs in and runs the import. All RLS checks pass naturally.
3. **New SECURITY DEFINER RPC that accepts a target tenant_id parameter.** The RPC runs with DEFINER privileges and can insert into any tenant. DANGEROUS — `auth_tenant_id()` checks are bypassed. If used, the RPC must verify the calling user is a super-admin or similar.

**Recommendation:** Option 1 (rewrite tenant_id) for the first version. Option 3 only if cross-tenant migration is a hard requirement, and only with super-admin gate.

### 6.3 Branch isolation

`post_stock_movement` checks `auth_has_branch(p_branch_id)` (line 231-233) — the calling user must be assigned to the branch. Direct warehouse insert has a similar check. The importer must either:
- Insert branches that the user has been assigned to, OR
- Go through SECURITY DEFINER RPCs with relaxed checks.

`user_branch_assignments` has no INSERT policy at all — this is the mechanism to assign the importing user to the newly imported branches. Either:
- The handle_new_user trigger pattern (SECURITY DEFINER), OR
- A new SECURITY DEFINER RPC that inserts assignments.

---

## 7. EXISTING PACKAGES + FEATURE-FOLDER CONVENTIONS

### 7.1 Packages already in pubspec.yaml

```yaml
# File: pubspec.yaml
file_picker: ^3.0.4      # line 51 — file pick dialog
csv: ^8.0.0              # line 52 — CSV parse/write
speech_to_text: ^7.4.0   # line 53
mobile_scanner: ^7.2.0   # line 47
pdf: ^3.12.0              # line 48
printing: ^5.14.3         # line 49
barcode: ^2.2.9           # line 50
```

**No new packages needed** for a migration import feature — `file_picker` + `csv` are already available.

### 7.2 Clean-arch pattern for a new feature folder

Existing features follow this structure:
```
lib/features/<name>/
  domain/
    entities/          # sealed class entities (immutable, equatable)
    failures/          # sealed class for typed failures
    repositories/      # abstract repository interface
    usecases/          # thin single-method classes, one per operation
  data/
    models/            # json → entity mappers (fromJson/toJson)
    datasources/       # ONE remote datasource with ALL Supabase calls
    repositories/      # repository impl (maps exceptions to typed failures)
  presentation/
    controllers/       # AsyncNotifier / Notifier providers
    pages/             # ConsumerWidget / ConsumerStatefulWidget pages
    widgets/           # reusable UI for this feature only
```

**Shared widgets** go in `lib/core/widgets/` (e.g., `PermissionGate`, `barcode_scan_page.dart`).
**Design tokens** in `lib/core/design/` (e.g., `AppButton`, `AppTextField`, `AppCard`).

### 7.3 How routes + hub entries are added

**Routes** are defined in `lib/router.dart`:
1. Import the page file at top
2. Add `GoRoute` in the routes list under the relevant parent (e.g., StatefulShellRoute for tabbed sections)
3. Example for import products: `lib/router.dart:48` — `import 'features/inventory/presentation/pages/import_products_page.dart';` + route `'/inventory/import'` (around line 332)
4. Use `context.push` for navigation

**Hub/settings entry points:** The `InventoryHubPage` (`lib/features/inventory/presentation/pages/inventory_hub_page.dart`) is a scrolling list of tappable rows. New feature rows are added to its column of children. Each row is a card with an icon, title, subtitle, and `onTap: () => context.push('/inventory/...')`. Example rows include Products, Barcode Templates, Categories, Brands, Warehouses, Stock Levels, Adjustments, Transfers, Stock Counts, IMEI Lookup.

**For migration import, the typical entry point would be:**
- A new hub row in InventoryHubPage: `'Import Data'` → `context.push('/inventory/import-migration')`
- OR a gear icon / menu item on the Settings page (`lib/features/auth/presentation/pages/settings_page.dart`)
- Route added in `lib/router.dart`

### 7.4 Controller pattern

Controllers are AsyncNotifiers (Riverpod):
```dart
final productsProvider = AsyncNotifierProvider<ProductsController, List<Product>>(
  ProductsController.new,
);
```

For migration import, an `AsyncNotifier` or a plain `Notifier` with `AsyncValue<ImportState>` would suffice. The F4 import page uses `ConsumerStatefulWidget` with manual `setState` — a controller pattern is also valid.

---

## SUMMARY OF CRITICAL FINDINGS

1. **Stock writes must go through `post_stock_movement` RPC.** Direct INSERT on `stock_balance`/`stock_ledger` is revoked. A new batch-RPC or loop over `post_stock_movement` is required.
2. **`post_stock_movement` forces tenant = auth_tenant_id().** CSV tenant_id is ignored. The importer migrates into their own tenant.
3. **SKU trigger respects explicit SKU.** Migration CSV can carry original SKUs — they will be preserved.
4. **`search_vector` auto-computed.** CSV does not need to supply it.
5. **`retail_price` does NOT exist.** Use `selling_price` (or `wholesale_price` / `min_selling_price` if needed).
6. **`slug` does NOT exist on `products`.** `sku` is the unique product key.
7. **FK order for import:** tenants → roles → permissions → users (requires auth.users entries first!) → branches → user_branch_assignments → categories → brands → products → warehouses → stock_balance (via post_stock_movement, which creates the stock_ledger row automatically via trigger).
8. **`users` table PK = FK to `auth.users(id)`.** Users must exist in Supabase Auth BEFORE their profile row can be inserted in `public.users`. This is a hard blocker for importing users from a CSV.
9. **Tables without INSERT RLS policies require SECURITY DEFINER RPCs:** tenants, roles, users, user_branch_assignments, permissions, stock_balance, stock_ledger.
10. **Tables with INSERT RLS but WITH CHECK `tenant_id = auth_tenant_id()`:** branches (ADMIN only), categories, brands, products, warehouses — the CSV tenant_id must match the logged-in user's tenant_id.
