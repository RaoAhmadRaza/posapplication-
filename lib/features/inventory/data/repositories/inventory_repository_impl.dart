import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/category.dart';
import '../../domain/entities/brand.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/entities/product_image.dart';
import '../../domain/entities/pricing_tier.dart';
import '../../domain/entities/barcode_template.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/repositories/inventory_repository.dart';
import '../datasources/inventory_remote_datasource.dart';
import '../models/category_model.dart';
import '../models/brand_model.dart';
import '../models/product_model.dart';
import '../models/product_variant_model.dart';
import '../models/product_image_model.dart';
import '../models/pricing_tier_model.dart';
import '../models/barcode_template_model.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl(ref.read(inventoryRemoteDataSourceProvider));
});

class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryRemoteDataSource _ds;

  InventoryRepositoryImpl(this._ds);

  InventoryFailure _mapError(Object e) {
    if (e is PostgrestException) {
      final code = e.code;
      if (code == '23505') {
        final msg = e.message.toLowerCase();
        if (msg.contains('sku') || msg.contains('barcode')) {
          return DuplicateSkuFailure();
        }
      }
      if (code == '42501') return PermissionDeniedFailure();
      if (code == 'PGRST116' || code == 'P0002') return NotFoundFailure();
    }
    if (e is AuthException) return PermissionDeniedFailure();
    if (e is SocketException || e is TimeoutException) {
      return NetworkFailure();
    }
    return UnknownFailure(e.toString());
  }

  // ==================== Categories ====================

  @override
  Future<(List<Category>, InventoryFailure?)> loadCategories() async {
    try {
      final rows = await _ds.loadCategories();
      return (rows.map(CategoryModel.fromJson).toList(), null);
    } catch (e) {
      return (<Category>[], _mapError(e));
    }
  }

  @override
  Future<(Category?, InventoryFailure?)> createCategory(Map<String, dynamic> data) async {
    try {
      final row = await _ds.createCategory(data);
      return (CategoryModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(Category?, InventoryFailure?)> updateCategory(String id, Map<String, dynamic> data) async {
    try {
      final row = await _ds.updateCategory(id, data);
      return (CategoryModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> deleteCategory(String id) async {
    try {
      await _ds.softDeleteCategory(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> deleteBrand(String id) async {
    try {
      await _ds.softDeleteBrand(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  // ==================== Brands ====================

  @override
  Future<(List<Brand>, InventoryFailure?)> loadBrands() async {
    try {
      final rows = await _ds.loadBrands();
      return (rows.map(BrandModel.fromJson).toList(), null);
    } catch (e) {
      return (<Brand>[], _mapError(e));
    }
  }

  @override
  Future<(Brand?, InventoryFailure?)> createBrand(Map<String, dynamic> data) async {
    try {
      final row = await _ds.createBrand(data);
      return (BrandModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(Brand?, InventoryFailure?)> updateBrand(String id, Map<String, dynamic> data) async {
    try {
      final row = await _ds.updateBrand(id, data);
      return (BrandModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  // ==================== Products ====================

  @override
  Future<(List<Product>, InventoryFailure?)> loadProducts({
    String? categoryId,
    String? brandId,
    String? status,
  }) async {
    try {
      final rows = await _ds.loadProducts(
        categoryId: categoryId,
        brandId: brandId,
        status: status,
      );
      return (rows.map(ProductModel.fromJson).toList(), null);
    } catch (e) {
      return (<Product>[], _mapError(e));
    }
  }

  @override
  Future<(List<Product>, InventoryFailure?)> searchProducts(String q) async {
    try {
      final rows = await _ds.searchProducts(q);
      return (rows.map(ProductModel.fromJson).toList(), null);
    } catch (e) {
      return (<Product>[], _mapError(e));
    }
  }

  @override
  Future<(Product?, InventoryFailure?)> getProduct(String id) async {
    try {
      final row = await _ds.getProduct(id);
      if (row == null) return (null, NotFoundFailure());
      return (ProductModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(Product?, InventoryFailure?)> createProduct(Map<String, dynamic> data) async {
    try {
      final row = await _ds.createProduct(data);
      return (ProductModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(Product?, InventoryFailure?)> updateProduct(String id, Map<String, dynamic> data) async {
    try {
      final row = await _ds.updateProduct(id, data);
      return (ProductModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> deleteProduct(String id) async {
    try {
      await _ds.softDeleteProduct(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  // ==================== Variants ====================

  @override
  Future<(List<ProductVariant>, InventoryFailure?)> loadVariants(String productId) async {
    try {
      final rows = await _ds.loadVariants(productId);
      return (rows.map(ProductVariantModel.fromJson).toList(), null);
    } catch (e) {
      return (<ProductVariant>[], _mapError(e));
    }
  }

  @override
  Future<(ProductVariant?, InventoryFailure?)> createVariant(Map<String, dynamic> data) async {
    try {
      final row = await _ds.createVariant(data);
      return (ProductVariantModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(ProductVariant?, InventoryFailure?)> updateVariant(String id, Map<String, dynamic> data) async {
    try {
      final row = await _ds.updateVariant(id, data);
      return (ProductVariantModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> deleteVariant(String id) async {
    try {
      await _ds.deleteVariant(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  // ==================== Images ====================

  @override
  Future<(List<ProductImage>, InventoryFailure?)> loadImages(String productId) async {
    try {
      final rows = await _ds.loadImages(productId);
      return (rows.map(ProductImageModel.fromJson).toList(), null);
    } catch (e) {
      return (<ProductImage>[], _mapError(e));
    }
  }

  @override
  Future<(ProductImage?, InventoryFailure?)> addImage(Map<String, dynamic> data) async {
    try {
      final row = await _ds.addImage(data);
      return (ProductImageModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> setPrimaryImage(String imageId) async {
    try {
      await _ds.setPrimaryImage(imageId);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> deleteImage(String id) async {
    try {
      await _ds.deleteImage(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  // ==================== Pricing Tiers ====================

  @override
  Future<(List<PricingTier>, InventoryFailure?)> loadPricingTiers(String productId) async {
    try {
      final rows = await _ds.loadPricingTiers(productId);
      return (rows.map(PricingTierModel.fromJson).toList(), null);
    } catch (e) {
      return (<PricingTier>[], _mapError(e));
    }
  }

  @override
  Future<(PricingTier?, InventoryFailure?)> createPricingTier(Map<String, dynamic> data) async {
    try {
      final row = await _ds.createPricingTier(data);
      return (PricingTierModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(PricingTier?, InventoryFailure?)> updatePricingTier(String id, Map<String, dynamic> data) async {
    try {
      final row = await _ds.updatePricingTier(id, data);
      return (PricingTierModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> deletePricingTier(String id) async {
    try {
      await _ds.deletePricingTier(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  // ==================== Barcode Templates ====================

  @override
  Future<(List<BarcodeTemplate>, InventoryFailure?)> loadBarcodeTemplates() async {
    try {
      final rows = await _ds.loadBarcodeTemplates();
      return (rows.map(BarcodeTemplateModel.fromJson).toList(), null);
    } catch (e) {
      return (<BarcodeTemplate>[], _mapError(e));
    }
  }

  @override
  Future<(BarcodeTemplate?, InventoryFailure?)> createBarcodeTemplate(Map<String, dynamic> data) async {
    try {
      final row = await _ds.createBarcodeTemplate(data);
      return (BarcodeTemplateModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(BarcodeTemplate?, InventoryFailure?)> updateBarcodeTemplate(String id, Map<String, dynamic> data) async {
    try {
      final row = await _ds.updateBarcodeTemplate(id, data);
      return (BarcodeTemplateModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }
}
