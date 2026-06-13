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
  }) async {
    var query = _client.from('products').select(_productCols);
    if (categoryId != null) query = query.eq('category_id', categoryId);
    if (brandId != null) query = query.eq('brand_id', brandId);
    if (status != null) query = query.eq('status', status);
    return query.order('created_at', ascending: false);
  }

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
    return list.first;
  }

  Future<void> setPrimaryImage(String imageId) async {
    final img = await _client
        .from('product_images')
        .select('product_id')
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
}
