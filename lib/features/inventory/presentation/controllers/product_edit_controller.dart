import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/entities/product_image.dart';
import '../../domain/entities/pricing_tier.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/get_product.dart';
import '../../domain/usecases/save_product.dart';
import '../../domain/usecases/delete_product.dart';
import '../../domain/usecases/load_variants.dart';
import '../../domain/usecases/save_variant.dart';
import '../../domain/usecases/delete_variant.dart';
import '../../domain/usecases/load_images.dart';
import '../../domain/usecases/save_image.dart';
import '../../domain/usecases/set_primary_image.dart';
import '../../domain/usecases/delete_image.dart';
import '../../domain/usecases/load_pricing_tiers.dart';
import '../../domain/usecases/save_pricing_tier.dart';
import '../../domain/usecases/delete_pricing_tier.dart';
import 'products_controller.dart';

final productEditProvider =
    NotifierProvider<ProductEditController, AsyncValue<Product?>>(
  ProductEditController.new,
);

class ProductVariantsState {
  final List<ProductVariant> variants;
  final bool loading;
  const ProductVariantsState({this.variants = const [], this.loading = false});
}

class ProductImagesState {
  final List<ProductImage> images;
  final bool loading;
  const ProductImagesState({this.images = const [], this.loading = false});
}

class ProductPricingState {
  final List<PricingTier> tiers;
  final bool loading;
  const ProductPricingState({this.tiers = const [], this.loading = false});
}

class ProductEditController extends Notifier<AsyncValue<Product?>> {
  var variantsState = const ProductVariantsState();
  var imagesState = const ProductImagesState();
  var pricingState = const ProductPricingState();
  String? editingId;

  @override
  AsyncValue<Product?> build() => const AsyncValue.data(null);

  Future<void> loadForEdit(String id) async {
    editingId = id;
    state = const AsyncValue.loading();
    final (product, failure) =
        await ref.read(getProductUseCaseProvider).call(id);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
      return;
    }
    state = AsyncValue.data(product);
    _loadSubResources();
  }

  Future<void> _loadSubResources() async {
    if (editingId == null) return;
    _loadVariants();
    _loadImages();
    _loadPricingTiers();
  }

  Future<void> _loadVariants() async {
    variantsState = ProductVariantsState(loading: true);
    final (variants, _) =
        await ref.read(loadVariantsUseCaseProvider).call(editingId!);
    variantsState = ProductVariantsState(variants: variants);
  }

  Future<void> _loadImages() async {
    imagesState = ProductImagesState(loading: true);
    final (images, _) =
        await ref.read(loadImagesUseCaseProvider).call(editingId!);
    imagesState = ProductImagesState(images: images);
  }

  Future<void> _loadPricingTiers() async {
    pricingState = ProductPricingState(loading: true);
    final (tiers, _) =
        await ref.read(loadPricingTiersUseCaseProvider).call(editingId!);
    pricingState = ProductPricingState(tiers: tiers);
  }

  Future<InventoryFailure?> saveProduct(Map<String, dynamic> data) async {
    final (product, failure) = await ref
        .read(saveProductUseCaseProvider)
        .call(data: data, id: editingId);
    if (failure != null) return failure;
    if (product != null && editingId == null) {
      editingId = product.id;
      state = AsyncValue.data(product);
    }
    ref.invalidate(productsProvider);
    return null;
  }

  Future<void> deleteProduct() async {
    if (editingId == null) return;
    await ref.read(deleteProductUseCaseProvider).call(editingId!);
  }

  // Variants
  Future<InventoryFailure?> saveVariant(Map<String, dynamic> data,
      {String? id}) async {
    final (_, failure) =
        await ref.read(saveVariantUseCaseProvider).call(data: data, id: id);
    if (failure != null) return failure;
    await _loadVariants();
    return null;
  }

  Future<void> deleteVariant(String id) async {
    await ref.read(deleteVariantUseCaseProvider).call(id);
    await _loadVariants();
  }

  // Images
  Future<InventoryFailure?> addImage(Map<String, dynamic> data) async {
    final (_, failure) =
        await ref.read(saveImageUseCaseProvider).call(data);
    if (failure != null) return failure;
    await _loadImages();
    return null;
  }

  Future<void> setPrimaryImage(String imageId) async {
    await ref.read(setPrimaryImageUseCaseProvider).call(imageId);
    await _loadImages();
  }

  Future<void> deleteImage(String id) async {
    await ref.read(deleteImageUseCaseProvider).call(id);
    await _loadImages();
  }

  // Pricing tiers
  Future<InventoryFailure?> savePricingTier(Map<String, dynamic> data,
      {String? id}) async {
    final (_, failure) =
        await ref.read(savePricingTierUseCaseProvider).call(data: data, id: id);
    if (failure != null) return failure;
    await _loadPricingTiers();
    return null;
  }

  Future<void> deletePricingTier(String id) async {
    await ref.read(deletePricingTierUseCaseProvider).call(id);
    await _loadPricingTiers();
  }
}
