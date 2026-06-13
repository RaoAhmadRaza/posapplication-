import '../../domain/entities/category.dart';
import '../../domain/entities/brand.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/entities/product_image.dart';
import '../../domain/entities/pricing_tier.dart';
import '../../domain/entities/barcode_template.dart';
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
  });
  Future<(List<Product>, InventoryFailure?)> searchProducts(String q);
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
}
