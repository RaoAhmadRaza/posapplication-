import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase.dart';

final inventoryRemoteDataSourceProvider = Provider<InventoryRemoteDataSource>((ref) {
  return InventoryRemoteDataSource(supabase);
});

class InventoryRemoteDataSource {
  final SupabaseClient _client;

  InventoryRemoteDataSource(this._client);

  String? _cachedTenantId;

  Future<String> _tenantId() async {
    if (_cachedTenantId != null) return _cachedTenantId!;
    final data = await _client
        .from('users')
        .select('tenant_id')
        .single();
    _cachedTenantId = data['tenant_id'] as String;
    return _cachedTenantId!;
  }

  String _slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  String? get _userId => _client.auth.currentUser?.id;

  // ==================== Categories ====================

  Future<List<Map<String, dynamic>>> loadCategories() async {
    return _client
        .from('categories')
        .select('id, tenant_id, name, slug, parent_id, description, image_url, sort_order, is_active')
        .order('sort_order');
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> data) async {
    final payload = {
      ...data,
      'tenant_id': await _tenantId(),
      'slug': _slugify(data['name'] as String),
      'created_by': _userId,
      'updated_by': _userId,
    };
    final list = await _client.from('categories').insert(payload).select();
    return list.first;
  }

  Future<Map<String, dynamic>> updateCategory(String id, Map<String, dynamic> data) async {
    if (data.containsKey('name')) {
      data['slug'] = _slugify(data['name'] as String);
    }
    data['updated_by'] = _userId;
    final list = await _client.from('categories').update(data).eq('id', id).select();
    return list.first;
  }

  Future<void> softDeleteCategory(String id) async {
    await _client.rpc('soft_delete_category', params: {'p_id': id});
  }

  // ==================== Brands ====================

  Future<List<Map<String, dynamic>>> loadBrands() async {
    return _client
        .from('brands')
        .select('id, tenant_id, name, slug, logo_url, description, is_active')
        .order('name');
  }

  Future<Map<String, dynamic>> createBrand(Map<String, dynamic> data) async {
    final payload = {
      ...data,
      'tenant_id': await _tenantId(),
      'slug': _slugify(data['name'] as String),
      'created_by': _userId,
      'updated_by': _userId,
    };
    final list = await _client.from('brands').insert(payload).select();
    return list.first;
  }

  Future<Map<String, dynamic>> updateBrand(String id, Map<String, dynamic> data) async {
    if (data.containsKey('name')) {
      data['slug'] = _slugify(data['name'] as String);
    }
    data['updated_by'] = _userId;
    final list = await _client.from('brands').update(data).eq('id', id).select();
    return list.first;
  }

  Future<void> softDeleteBrand(String id) async {
    await _client.rpc('soft_delete_brand', params: {'p_id': id});
  }

  // ==================== Products ====================

  static const _productCols = 'id, tenant_id, sku, name, description, barcode, type,'
      ' category_id, brand_id, unit_of_measure, cost_price, selling_price,'
      ' min_selling_price, wholesale_price, tax_rate, tax_inclusive, reorder_point,'
      ' reorder_qty, weight, is_active, status, image_url, tags';

  Future<List<Map<String, dynamic>>> loadProducts({
    String? categoryId,
    String? brandId,
    String? status,
    int page = 0,
    int pageSize = 200,
  }) async {
    var query = _client.from('products').select(_productCols);
    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (brandId != null) query = query.eq('brand_id', brandId);
    if (status != null) query = query.eq('status', status);
    final from = page * pageSize;
    return query
        .order('created_at', ascending: false)
        .range(from, from + pageSize - 1);
  }

  Future<List<Map<String, dynamic>>> searchProducts(
    String q, {
    String? categoryId,
    String? brandId,
    String? status,
  }) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) {
      return _client.from('products').select(_productCols).order('name').limit(50);
    }

    var query = _client
        .from('products')
        .select(_productCols)
        .or('name.ilike.*$trimmed*,sku.ilike.*$trimmed*,barcode.ilike.$trimmed');
    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (brandId != null) query = query.eq('brand_id', brandId);
    if (status != null) query = query.eq('status', status);
    return query.order('name').limit(50);
  }

  Future<Map<String, dynamic>?> getProduct(String id) async {
    final list = await _client.from('products').select(_productCols).eq('id', id);
    return list.isNotEmpty ? list.first : null;
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> data) async {
    final payload = {
      ...data,
      'tenant_id': await _tenantId(),
      'created_by': _userId,
      'updated_by': _userId,
    };
    final list = await _client.from('products').insert(payload).select();
    return list.first;
  }

  Future<Map<String, dynamic>> updateProduct(String id, Map<String, dynamic> data) async {
    data['updated_by'] = _userId;
    final list = await _client.from('products').update(data).eq('id', id).select();
    return list.first;
  }

  Future<void> softDeleteProduct(String id) async {
    await _client.rpc('soft_delete_product', params: {'p_id': id});
  }

  // ==================== Product Variants ====================

  Future<List<Map<String, dynamic>>> loadVariants(String productId) async {
    return _client
        .from('product_variants')
        .select('id, product_id, variant_name, sku, barcode, cost_price, selling_price, weight, attributes_json, is_active')
        .eq('product_id', productId)
        .order('created_at');
  }

  Future<Map<String, dynamic>> createVariant(Map<String, dynamic> data) async {
    final list = await _client.from('product_variants').insert(data).select();
    return list.first;
  }

  Future<Map<String, dynamic>> updateVariant(String id, Map<String, dynamic> data) async {
    final list = await _client.from('product_variants').update(data).eq('id', id).select();
    return list.first;
  }

  Future<void> deleteVariant(String id) async {
    await _client.from('product_variants').delete().eq('id', id);
  }

  // ==================== Product Images ====================

  Future<List<Map<String, dynamic>>> loadImages(String productId) async {
    return _client
        .from('product_images')
        .select('id, product_id, url, alt_text, sort_order, is_primary')
        .eq('product_id', productId)
        .order('sort_order');
  }

  Future<Map<String, dynamic>> addImage(Map<String, dynamic> data) async {
    final list = await _client.from('product_images').insert(data).select();
    final row = list.first;
    // Denormalize primary image onto products.image_url so the catalog list
    // (which reads image_url, not a join) shows a thumbnail.
    if (row['is_primary'] == true) {
      await _client
          .from('products')
          .update({'image_url': row['url']}).eq('id', row['product_id']);
    }
    return row;
  }

  // Uploads image bytes to the public 'product-images' bucket under
  // <tenant_id>/<product_id>/<timestamp>.<ext> and returns the public URL.
  Future<String> uploadProductImage(
    String productId,
    Uint8List bytes,
    String ext,
  ) async {
    final tenant = await _tenantId();
    final safeExt = ext.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final path =
        '$tenant/$productId/${DateTime.now().millisecondsSinceEpoch}.$safeExt';
    await _client.storage.from('product-images').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _imageContentType(safeExt)),
        );
    return _client.storage.from('product-images').getPublicUrl(path);
  }

  String _imageContentType(String ext) => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        _ => 'image/jpeg',
      };

  Future<void> setPrimaryImage(String imageId) async {
    final img = await _client
        .from('product_images')
        .select('product_id, url')
        .eq('id', imageId)
        .single();
    final productId = img['product_id'] as String;
    await _client
        .from('product_images')
        .update({'is_primary': false})
        .eq('product_id', productId);
    await _client
        .from('product_images')
        .update({'is_primary': true})
        .eq('id', imageId);
    await _client
        .from('products')
        .update({'image_url': img['url']}).eq('id', productId);
  }

  Future<void> deleteImage(String id) async {
    await _client.from('product_images').delete().eq('id', id);
  }

  // ==================== Pricing Tiers ====================

  Future<List<Map<String, dynamic>>> loadPricingTiers(String productId) async {
    return _client
        .from('product_pricing_tiers')
        .select('id, product_id, tier_name, customer_group_id, min_qty, max_qty, unit_price, discount_pct, valid_from, valid_until, is_active')
        .eq('product_id', productId)
        .order('min_qty');
  }

  Future<Map<String, dynamic>> createPricingTier(Map<String, dynamic> data) async {
    final list = await _client.from('product_pricing_tiers').insert(data).select();
    return list.first;
  }

  Future<Map<String, dynamic>> updatePricingTier(String id, Map<String, dynamic> data) async {
    final list = await _client.from('product_pricing_tiers').update(data).eq('id', id).select();
    return list.first;
  }

  Future<void> deletePricingTier(String id) async {
    await _client.from('product_pricing_tiers').delete().eq('id', id);
  }

  // ==================== Barcode Templates ====================

  Future<List<Map<String, dynamic>>> loadBarcodeTemplates() async {
    return _client
        .from('barcode_templates')
        .select('id, tenant_id, name, format, width_mm, height_mm, layout_json, is_default')
        .order('name');
  }

  Future<Map<String, dynamic>> createBarcodeTemplate(Map<String, dynamic> data) async {
    final list = await _client.from('barcode_templates').insert({
      ...data,
      'tenant_id': await _tenantId(),
    }).select();
    return list.first;
  }

  Future<Map<String, dynamic>> updateBarcodeTemplate(String id, Map<String, dynamic> data) async {
    final list = await _client.from('barcode_templates').update(data).eq('id', id).select();
    return list.first;
  }

  // ==================== Warehouses ====================

  static const _warehouseCols = 'id, tenant_id, branch_id, name, code, address, capacity_notes, is_active, is_default';

  Future<List<Map<String, dynamic>>> loadWarehouses({String? branchId}) async {
    var query = _client.from('warehouses').select(_warehouseCols);
    if (branchId != null) query = query.eq('branch_id', branchId);
    return query.order('name');
  }

  Future<Map<String, dynamic>> createWarehouse(Map<String, dynamic> data) async {
    final payload = {
      ...data,
      'tenant_id': await _tenantId(),
      'created_by': _userId,
      'updated_by': _userId,
    };
    final list = await _client.from('warehouses').insert(payload).select();
    return list.first;
  }

  Future<Map<String, dynamic>> updateWarehouse(String id, Map<String, dynamic> data) async {
    data['updated_by'] = _userId;
    final list = await _client.from('warehouses').update(data).eq('id', id).select();
    return list.first;
  }

  Future<void> softDeleteWarehouse(String id) async {
    await _client.rpc('soft_delete_warehouse', params: {'p_id': id});
  }

  Future<void> setDefaultWarehouse(String id) async {
    await _client.rpc('set_default_warehouse', params: {'p_id': id});
  }

  Future<Map<String, dynamic>> ensureDefaultWarehouse(String branchId) async {
    final result = await _client.rpc('ensure_default_warehouse', params: {'p_branch_id': branchId});
    return result as Map<String, dynamic>;
  }

  // ==================== Stock Balance ====================

  static const _balanceCols = 'id, branch_id, warehouse_id, product_id, variant_id,'
      ' qty_on_hand, qty_reserved, qty_in_transit, avg_cost, reorder_point, last_stock_take, last_updated';

  Future<List<Map<String, dynamic>>> loadStockBalances({
    String? branchId,
    String? warehouseId,
    String? productId,
  }) async {
    var query = _client.from('stock_balance').select(_balanceCols);
    if (branchId != null) query = query.eq('branch_id', branchId);
    if (warehouseId != null) {
      query = query.eq('warehouse_id', warehouseId);
    } else {
      query = query.isFilter('warehouse_id', null);
    }
    if (productId != null) query = query.eq('product_id', productId);
    return query.order('product_id');
  }

  // ==================== Stock Ledger ====================

  static const _ledgerCols = 'id, product_id, variant_id, branch_id, warehouse_id,'
      ' operation_type, qty_change, cost_per_unit, total_cost, balance_after,'
      ' avg_cost_after, reference_type, reference_id, notes, created_at';

  Future<List<Map<String, dynamic>>> loadProductLedger(
    String productId, {
    String? branchId,
    String? warehouseId,
  }) async {
    var query = _client.from('stock_ledger').select(_ledgerCols).eq('product_id', productId);
    if (branchId != null) query = query.eq('branch_id', branchId);
    if (warehouseId != null) {
      query = query.eq('warehouse_id', warehouseId);
    } else {
      query = query.isFilter('warehouse_id', null);
    }
    return query.order('created_at', ascending: false);
  }

  // ==================== Products Stock (branch-wide) ====================

  Future<Map<String, double>> loadProductsStock({
    required String branchId,
  }) async {
    final rows = await _client
        .from('stock_balance')
        .select('product_id, qty_on_hand')
        .eq('branch_id', branchId)
        .isFilter('warehouse_id', null);
    return {
      for (final r in rows)
        r['product_id'] as String: (r['qty_on_hand'] as num).toDouble(),
    };
  }

  // ==================== Stock Levels (joined with products) ====================

  Future<List<Map<String, dynamic>>> loadStockLevels({
    String? branchId,
    String? warehouseId,
  }) async {
    var query = _client.from('stock_balance').select(
      'product_id, warehouse_id, variant_id, qty_on_hand, qty_reserved,'
      ' qty_in_transit, avg_cost, products!inner(name, sku, reorder_point)',
    );
    if (branchId != null) query = query.eq('branch_id', branchId);
    if (warehouseId != null) {
      query = query.eq('warehouse_id', warehouseId);
    } else {
      query = query.isFilter('warehouse_id', null);
    }
    return query.order('product_id');
  }

  // ==================== Stock Movement (RPC) ====================

  Future<Map<String, dynamic>> postStockMovement({
    required String branchId,
    required String? warehouseId,
    required String productId,
    required String? variantId,
    required String operationType,
    required double qtyChange,
    required double costPerUnit,
    required String referenceType,
    required String referenceId,
    String? notes,
  }) async {
    final result = await _client.rpc('post_stock_movement', params: {
      'p_branch_id': branchId,
      'p_warehouse_id': warehouseId,
      'p_product_id': productId,
      'p_variant_id': variantId,
      'p_operation_type': operationType,
      'p_qty_change': qtyChange,
      'p_cost_per_unit': costPerUnit,
      'p_reference_type': referenceType,
      'p_reference_id': referenceId,
      'p_notes': notes,
    });
    return result as Map<String, dynamic>;
  }

  // ==================== Stock Adjustments ====================

  static const _adjustmentCols = 'id, tenant_id, branch_id, warehouse_id, product_id, variant_id,'
      ' adj_qty, cost_per_unit, reason_code, reason_notes, reference_number, requires_approval,'
      ' approved_by, approved_at, posted, created_at, created_by';

  Future<List<Map<String, dynamic>>> loadAdjustments({
    String? branchId,
    bool pendingOnly = false,
  }) async {
    var query = _client.from('stock_adjustments').select(_adjustmentCols);
    if (branchId != null) query = query.eq('branch_id', branchId);
    if (pendingOnly) query = query.eq('requires_approval', true).filter('approved_by', 'is', null);
    return query.order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> createAdjustment({
    required String branchId,
    required String? warehouseId,
    required String productId,
    required String? variantId,
    required double adjQty,
    required double costPerUnit,
    required String reasonCode,
    String? notes,
  }) async {
    final result = await _client.rpc('create_stock_adjustment', params: {
      'p_branch_id': branchId,
      'p_warehouse_id': warehouseId,
      'p_product_id': productId,
      'p_variant_id': variantId,
      'p_adj_qty': adjQty,
      'p_cost_per_unit': costPerUnit,
      'p_reason': reasonCode,
      'p_notes': notes,
    });
    return result as Map<String, dynamic>;
  }

  Future<void> approveAdjustment(String id) async {
    await _client.rpc('approve_stock_adjustment', params: {'p_id': id});
  }

  // ==================== Stock Transfers ====================

  static const _transferCols = 'id, tenant_id, transfer_number, from_branch_id, to_branch_id,'
      ' from_warehouse_id, to_warehouse_id, status, dispatched_at, dispatched_by,'
      ' received_at, received_by, notes, created_at, updated_at, created_by, updated_by';

  Future<List<Map<String, dynamic>>> loadTransfers({
    String? branchId,
    String? direction,
  }) async {
    var query = _client.from('stock_transfers').select(_transferCols);
    if (branchId != null && direction == 'outgoing') {
      query = query.eq('from_branch_id', branchId);
    } else if (branchId != null && direction == 'incoming') {
      query = query.eq('to_branch_id', branchId);
    } else if (branchId != null) {
      query = query.or('from_branch_id.eq.$branchId,to_branch_id.eq.$branchId');
    }
    return query.order('created_at', ascending: false);
  }

  static const _transferItemCols = 'id, transfer_id, product_id, variant_id, imei_id,'
      ' qty, qty_received, cost_price, notes, created_at';

  Future<List<Map<String, dynamic>>> loadTransferItems(String transferId) async {
    return _client.from('stock_transfer_items').select(_transferItemCols)
        .eq('transfer_id', transferId).order('created_at');
  }

  Future<Map<String, dynamic>> createTransfer({
    required String fromBranchId,
    required String toBranchId,
    required String? fromWarehouseId,
    required String? toWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final result = await _client.rpc('create_stock_transfer', params: {
      'p_from_branch': fromBranchId,
      'p_to_branch': toBranchId,
      'p_from_wh': fromWarehouseId,
      'p_to_wh': toWarehouseId,
      'p_items': items,
      'p_notes': notes,
    });
    return result as Map<String, dynamic>;
  }

  Future<void> dispatchTransfer(String id) async {
    await _client.rpc('dispatch_stock_transfer', params: {'p_id': id});
  }

  Future<void> receiveTransfer(String id, List<Map<String, dynamic>> received) async {
    await _client.rpc('receive_stock_transfer', params: {
      'p_id': id,
      'p_received': received,
    });
  }

  Future<void> cancelTransfer(String id) async {
    await _client.rpc('cancel_stock_transfer', params: {'p_id': id});
  }

  // ==================== Stock Counts ====================

  static const _countCols = 'id, tenant_id, branch_id, warehouse_id, count_number, status,'
      ' category_id, started_at, completed_at, total_items, items_counted, variance_count,'
      ' notes, created_at, updated_at, created_by, updated_by';

  Future<List<Map<String, dynamic>>> loadCounts() async {
    return _client.from('stock_counts').select(_countCols)
        .order('created_at', ascending: false);
  }

  static const _countItemCols = 'id, stock_count_id, product_id, variant_id, system_qty,'
      ' counted_qty, variance, variance_cost, notes, counted_at, counted_by, created_at';

  Future<List<Map<String, dynamic>>> loadCountItems(String countId) async {
    return _client.from('stock_count_items').select(_countItemCols)
        .eq('stock_count_id', countId).order('created_at');
  }

  Future<Map<String, dynamic>> openCount({
    required String branchId,
    String? warehouseId,
    String? categoryId,
  }) async {
    final result = await _client.rpc('open_stock_count', params: {
      'p_branch': branchId,
      'p_warehouse': warehouseId,
      'p_category': categoryId,
    });
    return result as Map<String, dynamic>;
  }

  Future<void> recordCountItem(String itemId, double counted) async {
    await _client.rpc('record_count_item', params: {
      'p_item_id': itemId,
      'p_counted': counted,
    });
  }

  Future<void> completeCount(String id) async {
    await _client.rpc('complete_stock_count', params: {'p_id': id});
  }

  // ==================== IMEI Records ====================

  static const _imeiCols = 'id, tenant_id, imei, product_id, variant_id, status, branch_id,'
      ' warehouse_id, source_type, source_id, cost_price, selling_price, warranty_expires_at,'
      ' notes, created_at, updated_at, created_by, updated_by';

  Future<List<Map<String, dynamic>>> loadImei({
    String? productId,
    String? status,
  }) async {
    var query = _client.from('imei_records').select(_imeiCols);
    if (productId != null) query = query.eq('product_id', productId);
    if (status != null) query = query.eq('status', status);
    return query.order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> registerImei({
    required String productId,
    required String? variantId,
    required String branchId,
    required String? warehouseId,
    required String imei,
    required String sourceType,
    required double costPrice,
    bool postStock = true,
  }) async {
    final result = await _client.rpc('register_imei', params: {
      'p_product': productId,
      'p_variant': variantId,
      'p_branch': branchId,
      'p_warehouse': warehouseId,
      'p_imei': imei,
      'p_source_type': sourceType,
      'p_cost': costPrice,
      'p_post_stock': postStock,
    });
    return result as Map<String, dynamic>;
  }

  // ==================== Inventory Settings ====================

  Future<Map<String, dynamic>> loadInventorySettings() async {
    final tid = await _tenantId();
    final list = await _client.from('inventory_settings')
        .select('tenant_id, adjustment_approval_threshold, allow_negative_stock, updated_at')
        .eq('tenant_id', tid);
    return list.isNotEmpty ? list.first : <String, dynamic>{
      'tenant_id': tid,
      'adjustment_approval_threshold': 0,
      'allow_negative_stock': false,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> updateApprovalThreshold(double value) async {
    final tid = await _tenantId();
    await _client.from('inventory_settings').update({
      'adjustment_approval_threshold': value,
    }).eq('tenant_id', tid);
  }

  Future<Map<String, dynamic>> bulkImportProducts(
      List<Map<String, dynamic>> rows) async {
    final result = await _client.rpc('bulk_import_products', params: {
      'p_rows': rows,
    });
    return Map<String, dynamic>.from(result as Map);
  }
}
