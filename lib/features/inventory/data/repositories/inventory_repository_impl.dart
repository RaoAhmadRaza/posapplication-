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
import '../../domain/entities/warehouse.dart';
import '../../domain/entities/stock_balance.dart';
import '../../domain/entities/stock_ledger_entry.dart';
import '../../domain/entities/stock_level.dart';
import '../../domain/entities/stock_adjustment.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/entities/stock_transfer_item.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/entities/stock_count_item.dart';
import '../../domain/entities/imei_record.dart';
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
import '../models/warehouse_model.dart';
import '../models/stock_balance_model.dart';
import '../models/stock_ledger_entry_model.dart';
import '../models/stock_level_model.dart';
import '../models/stock_adjustment_model.dart';
import '../models/stock_transfer_model.dart';
import '../models/stock_transfer_item_model.dart';
import '../models/stock_count_model.dart';
import '../models/stock_count_item_model.dart';
import '../models/imei_record_model.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepositoryImpl(ref.read(inventoryRemoteDataSourceProvider));
});

class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryRemoteDataSource _ds;

  InventoryRepositoryImpl(this._ds);

  InventoryFailure _mapError(Object e) {
    if (e is PostgrestException) {
      final code = e.code;
      final msg = e.message.toLowerCase();
      if (code == '23505') {
        if (msg.contains('imei')) return DuplicateImeiFailure();
        if (msg.contains('sku') || msg.contains('barcode')) {
          return DuplicateSkuFailure();
        }
      }
      if (code == 'P0001') {
        if (msg.contains('warehouse has stock')) return WarehouseHasStockFailure();
        if (msg.contains('stock')) return InsufficientStockFailure();
      }
      if (code == '22000') return InvalidTransitionFailure();
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
  Future<(List<Product>, InventoryFailure?)> searchProducts(
    String q, {
    String? categoryId,
    String? brandId,
    String? status,
  }) async {
    try {
      final rows = await _ds.searchProducts(
        q,
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

  // ==================== Warehouses ====================

  @override
  Future<(List<Warehouse>, InventoryFailure?)> loadWarehouses({String? branchId}) async {
    try {
      final rows = await _ds.loadWarehouses(branchId: branchId);
      return (rows.map(WarehouseModel.fromJson).toList(), null);
    } catch (e) {
      return (<Warehouse>[], _mapError(e));
    }
  }

  @override
  Future<(Warehouse?, InventoryFailure?)> createWarehouse(Map<String, dynamic> data) async {
    try {
      final row = await _ds.createWarehouse(data);
      return (WarehouseModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(Warehouse?, InventoryFailure?)> updateWarehouse(String id, Map<String, dynamic> data) async {
    try {
      final row = await _ds.updateWarehouse(id, data);
      return (WarehouseModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> deleteWarehouse(String id) async {
    try {
      await _ds.softDeleteWarehouse(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> setDefaultWarehouse(String id) async {
    try {
      await _ds.setDefaultWarehouse(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(Warehouse?, InventoryFailure?)> ensureDefaultWarehouse(String branchId) async {
    try {
      final row = await _ds.ensureDefaultWarehouse(branchId);
      return (WarehouseModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  // ==================== Stock Balance ====================

  @override
  Future<(List<StockBalance>, InventoryFailure?)> loadStockBalances({
    String? branchId,
    String? warehouseId,
    String? productId,
  }) async {
    try {
      final rows = await _ds.loadStockBalances(
        branchId: branchId,
        warehouseId: warehouseId,
        productId: productId,
      );
      return (rows.map(StockBalanceModel.fromJson).toList(), null);
    } catch (e) {
      return (<StockBalance>[], _mapError(e));
    }
  }

  // ==================== Stock Ledger ====================

  @override
  Future<(List<StockLedgerEntry>, InventoryFailure?)> loadProductLedger(
    String productId, {
    String? branchId,
    String? warehouseId,
  }) async {
    try {
      final rows = await _ds.loadProductLedger(
        productId,
        branchId: branchId,
        warehouseId: warehouseId,
      );
      return (rows.map(StockLedgerEntryModel.fromJson).toList(), null);
    } catch (e) {
      return (<StockLedgerEntry>[], _mapError(e));
    }
  }

  // ==================== Stock Movement ====================

  @override
  Future<(StockBalance?, InventoryFailure?)> postStockMovement({
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
    try {
      final row = await _ds.postStockMovement(
        branchId: branchId,
        warehouseId: warehouseId,
        productId: productId,
        variantId: variantId,
        operationType: operationType,
        qtyChange: qtyChange,
        costPerUnit: costPerUnit,
        referenceType: referenceType,
        referenceId: referenceId,
        notes: notes,
      );
      return (StockBalanceModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  // ==================== Stock Levels ====================

  @override
  Future<(List<StockLevel>, InventoryFailure?)> loadStockLevels({
    String? branchId,
    String? warehouseId,
  }) async {
    try {
      final rows = await _ds.loadStockLevels(
        branchId: branchId,
        warehouseId: warehouseId,
      );
      return (rows.map(StockLevelModel.fromJson).toList(), null);
    } catch (e) {
      return (<StockLevel>[], _mapError(e));
    }
  }

  // ==================== Stock Adjustments ====================

  @override
  Future<(List<StockAdjustment>, InventoryFailure?)> loadAdjustments({
    String? branchId,
    bool pendingOnly = false,
  }) async {
    try {
      final rows = await _ds.loadAdjustments(branchId: branchId, pendingOnly: pendingOnly);
      return (rows.map(StockAdjustmentModel.fromJson).toList(), null);
    } catch (e) {
      return (<StockAdjustment>[], _mapError(e));
    }
  }

  @override
  Future<(StockAdjustment?, InventoryFailure?)> createAdjustment({
    required String branchId,
    required String? warehouseId,
    required String productId,
    required String? variantId,
    required double adjQty,
    required double costPerUnit,
    required String reasonCode,
    String? notes,
  }) async {
    try {
      final row = await _ds.createAdjustment(
        branchId: branchId,
        warehouseId: warehouseId,
        productId: productId,
        variantId: variantId,
        adjQty: adjQty,
        costPerUnit: costPerUnit,
        reasonCode: reasonCode,
        notes: notes,
      );
      return (StockAdjustmentModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> approveAdjustment(String id) async {
    try {
      await _ds.approveAdjustment(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  // ==================== Stock Transfers ====================

  @override
  Future<(List<StockTransfer>, InventoryFailure?)> loadTransfers({
    String? branchId,
    String? direction,
  }) async {
    try {
      final rows = await _ds.loadTransfers(branchId: branchId, direction: direction);
      return (rows.map(StockTransferModel.fromJson).toList(), null);
    } catch (e) {
      return (<StockTransfer>[], _mapError(e));
    }
  }

  @override
  Future<(List<StockTransferItem>, InventoryFailure?)> loadTransferItems(String transferId) async {
    try {
      final rows = await _ds.loadTransferItems(transferId);
      return (rows.map(StockTransferItemModel.fromJson).toList(), null);
    } catch (e) {
      return (<StockTransferItem>[], _mapError(e));
    }
  }

  @override
  Future<(StockTransfer?, InventoryFailure?)> createTransfer({
    required String fromBranchId,
    required String toBranchId,
    required String? fromWarehouseId,
    required String? toWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final row = await _ds.createTransfer(
        fromBranchId: fromBranchId,
        toBranchId: toBranchId,
        fromWarehouseId: fromWarehouseId,
        toWarehouseId: toWarehouseId,
        items: items,
        notes: notes,
      );
      return (StockTransferModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> dispatchTransfer(String id) async {
    try {
      await _ds.dispatchTransfer(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> receiveTransfer(String id, List<Map<String, dynamic>> received) async {
    try {
      await _ds.receiveTransfer(id, received);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> cancelTransfer(String id) async {
    try {
      await _ds.cancelTransfer(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  // ==================== Stock Counts ====================

  @override
  Future<(List<StockCount>, InventoryFailure?)> loadCounts() async {
    try {
      final rows = await _ds.loadCounts();
      return (rows.map(StockCountModel.fromJson).toList(), null);
    } catch (e) {
      return (<StockCount>[], _mapError(e));
    }
  }

  @override
  Future<(List<StockCountItem>, InventoryFailure?)> loadCountItems(String countId) async {
    try {
      final rows = await _ds.loadCountItems(countId);
      return (rows.map(StockCountItemModel.fromJson).toList(), null);
    } catch (e) {
      return (<StockCountItem>[], _mapError(e));
    }
  }

  @override
  Future<(StockCount?, InventoryFailure?)> openCount({
    required String branchId,
    String? warehouseId,
    String? categoryId,
  }) async {
    try {
      final row = await _ds.openCount(
        branchId: branchId,
        warehouseId: warehouseId,
        categoryId: categoryId,
      );
      return (StockCountModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> recordCountItem(String itemId, double counted) async {
    try {
      await _ds.recordCountItem(itemId, counted);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> completeCount(String id) async {
    try {
      await _ds.completeCount(id);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  // ==================== IMEI Records ====================

  @override
  Future<(List<ImeiRecord>, InventoryFailure?)> loadImei({
    String? productId,
    String? status,
  }) async {
    try {
      final rows = await _ds.loadImei(productId: productId, status: status);
      return (rows.map(ImeiRecordModel.fromJson).toList(), null);
    } catch (e) {
      return (<ImeiRecord>[], _mapError(e));
    }
  }

  @override
  Future<(ImeiRecord?, InventoryFailure?)> registerImei({
    required String productId,
    required String? variantId,
    required String branchId,
    required String? warehouseId,
    required String imei,
    required String sourceType,
    required double costPrice,
    bool postStock = true,
  }) async {
    try {
      final row = await _ds.registerImei(
        productId: productId,
        variantId: variantId,
        branchId: branchId,
        warehouseId: warehouseId,
        imei: imei,
        sourceType: sourceType,
        costPrice: costPrice,
        postStock: postStock,
      );
      return (ImeiRecordModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  // ==================== Inventory Settings ====================

  @override
  Future<(Map<String, dynamic>, InventoryFailure?)> loadInventorySettings() async {
    try {
      final row = await _ds.loadInventorySettings();
      return (row, null);
    } catch (e) {
      return (<String, dynamic>{}, _mapError(e));
    }
  }

  @override
  Future<(bool, InventoryFailure?)> updateApprovalThreshold(double value) async {
    try {
      await _ds.updateApprovalThreshold(value);
      return (true, null);
    } catch (e) {
      return (false, _mapError(e));
    }
  }

  @override
  Future<(Map<String, dynamic>, InventoryFailure?)> bulkImportProducts(
      List<Map<String, dynamic>> rows) async {
    try {
      final result = await _ds.bulkImportProducts(rows);
      return (result, null);
    } catch (e) {
      return (<String, dynamic>{}, _mapError(e));
    }
  }
}
