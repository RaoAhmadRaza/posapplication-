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

abstract class InventoryRepository {
  Future<(List<Category>, InventoryFailure?)> loadCategories();
  Future<(Category?, InventoryFailure?)> createCategory(Map<String, dynamic> data);
  Future<(Category?, InventoryFailure?)> updateCategory(String id, Map<String, dynamic> data);
  Future<(bool, InventoryFailure?)> deleteCategory(String id);

  Future<(List<Brand>, InventoryFailure?)> loadBrands();
  Future<(Brand?, InventoryFailure?)> createBrand(Map<String, dynamic> data);
  Future<(Brand?, InventoryFailure?)> updateBrand(String id, Map<String, dynamic> data);
  Future<(bool, InventoryFailure?)> deleteBrand(String id);

  Future<(List<Product>, InventoryFailure?)> loadProducts({
    String? categoryId,
    String? brandId,
    String? status,
    int page,
    int pageSize,
  });
  Future<(List<Product>, InventoryFailure?)> searchProducts(
    String q, {
    String? categoryId,
    String? brandId,
    String? status,
  });
  Future<(Product?, InventoryFailure?)> getProduct(String id);
  Future<(Product?, InventoryFailure?)> createProduct(Map<String, dynamic> data);
  Future<(Product?, InventoryFailure?)> updateProduct(String id, Map<String, dynamic> data);
  Future<(bool, InventoryFailure?)> deleteProduct(String id);

  Future<(List<ProductVariant>, InventoryFailure?)> loadVariants(String productId);
  Future<(ProductVariant?, InventoryFailure?)> createVariant(Map<String, dynamic> data);
  Future<(ProductVariant?, InventoryFailure?)> updateVariant(String id, Map<String, dynamic> data);
  Future<(bool, InventoryFailure?)> deleteVariant(String id);

  Future<(List<ProductImage>, InventoryFailure?)> loadImages(String productId);
  Future<(ProductImage?, InventoryFailure?)> addImage(Map<String, dynamic> data);
  Future<(bool, InventoryFailure?)> setPrimaryImage(String imageId);
  Future<(bool, InventoryFailure?)> deleteImage(String id);

  Future<(List<PricingTier>, InventoryFailure?)> loadPricingTiers(String productId);
  Future<(PricingTier?, InventoryFailure?)> createPricingTier(Map<String, dynamic> data);
  Future<(PricingTier?, InventoryFailure?)> updatePricingTier(String id, Map<String, dynamic> data);
  Future<(bool, InventoryFailure?)> deletePricingTier(String id);

  Future<(List<BarcodeTemplate>, InventoryFailure?)> loadBarcodeTemplates();
  Future<(BarcodeTemplate?, InventoryFailure?)> createBarcodeTemplate(Map<String, dynamic> data);
  Future<(BarcodeTemplate?, InventoryFailure?)> updateBarcodeTemplate(String id, Map<String, dynamic> data);

  Future<(List<Warehouse>, InventoryFailure?)> loadWarehouses({String? branchId});
  Future<(Warehouse?, InventoryFailure?)> createWarehouse(Map<String, dynamic> data);
  Future<(Warehouse?, InventoryFailure?)> updateWarehouse(String id, Map<String, dynamic> data);
  Future<(bool, InventoryFailure?)> deleteWarehouse(String id);
  Future<(bool, InventoryFailure?)> setDefaultWarehouse(String id);
  Future<(Warehouse?, InventoryFailure?)> ensureDefaultWarehouse(String branchId);

  Future<(List<StockBalance>, InventoryFailure?)> loadStockBalances({
    String? branchId,
    String? warehouseId,
    String? productId,
  });
  Future<(List<StockLedgerEntry>, InventoryFailure?)> loadProductLedger(
    String productId, {
    String? branchId,
    String? warehouseId,
  });
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
  });

  Future<(Map<String, double>, InventoryFailure?)> loadProductsStock({
    required String branchId,
  });

  Future<(List<StockLevel>, InventoryFailure?)> loadStockLevels({
    String? branchId,
    String? warehouseId,
  });

  Future<(List<StockAdjustment>, InventoryFailure?)> loadAdjustments({
    String? branchId,
    bool pendingOnly = false,
  });
  Future<(StockAdjustment?, InventoryFailure?)> createAdjustment({
    required String branchId,
    required String? warehouseId,
    required String productId,
    required String? variantId,
    required double adjQty,
    required double costPerUnit,
    required String reasonCode,
    String? notes,
  });
  Future<(bool, InventoryFailure?)> approveAdjustment(String id);

  Future<(List<StockTransfer>, InventoryFailure?)> loadTransfers({
    String? branchId,
    String? direction,
  });
  Future<(List<StockTransferItem>, InventoryFailure?)> loadTransferItems(String transferId);
  Future<(StockTransfer?, InventoryFailure?)> createTransfer({
    required String fromBranchId,
    required String toBranchId,
    required String? fromWarehouseId,
    required String? toWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  });
  Future<(bool, InventoryFailure?)> dispatchTransfer(String id);
  Future<(bool, InventoryFailure?)> receiveTransfer(String id, List<Map<String, dynamic>> received);
  Future<(bool, InventoryFailure?)> cancelTransfer(String id);

  Future<(List<StockCount>, InventoryFailure?)> loadCounts();
  Future<(List<StockCountItem>, InventoryFailure?)> loadCountItems(String countId);
  Future<(StockCount?, InventoryFailure?)> openCount({
    required String branchId,
    String? warehouseId,
    String? categoryId,
  });
  Future<(bool, InventoryFailure?)> recordCountItem(String itemId, double counted);
  Future<(bool, InventoryFailure?)> completeCount(String id);

  Future<(List<ImeiRecord>, InventoryFailure?)> loadImei({
    String? productId,
    String? status,
  });
  Future<(ImeiRecord?, InventoryFailure?)> registerImei({
    required String productId,
    required String? variantId,
    required String branchId,
    required String? warehouseId,
    required String imei,
    required String sourceType,
    required double costPrice,
    bool postStock = true,
  });

  Future<(Map<String, dynamic>, InventoryFailure?)> loadInventorySettings();
  Future<(bool, InventoryFailure?)> updateApprovalThreshold(double value);
  Future<(Map<String, dynamic>, InventoryFailure?)> bulkImportProducts(
      List<Map<String, dynamic>> rows);
}
