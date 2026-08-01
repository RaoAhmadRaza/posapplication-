import 'dart:typed_data';
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
import '../../domain/usecases/upload_product_image.dart';
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

  // Sub-resource states (variants/images/pricing) live outside `state`, so a
  // reload alone won't rebuild listeners. Re-emit `state` to notify; the always-
  // true override lets an equal value through.
  @override
  bool updateShouldNotify(
          AsyncValue<Product?> previous, AsyncValue<Product?> next) =>
      true;

  void _notify() => state = AsyncValue.data(state.value);

  /// Resets the controller for a fresh "New product" form. This Notifier is not
  /// autoDispose, so without it `editingId` survives from the previously opened
  /// product and the next save updates THAT product instead of inserting a new
  /// one (and the old product's variants/images/tiers show on the new form).
  void startNew() {
    editingId = null;
    variantsState = const ProductVariantsState();
    imagesState = const ProductImagesState();
    pricingState = const ProductPricingState();
    state = const AsyncValue.data(null);
  }

  Future<void> loadForEdit(String id) async {
    if (id != editingId) startNew(); // drop the previous product's sub-resources
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
    _notify();
  }

  Future<void> _loadImages() async {
    imagesState = ProductImagesState(loading: true);
    final (images, _) =
        await ref.read(loadImagesUseCaseProvider).call(editingId!);
    imagesState = ProductImagesState(images: images);
    _notify();
  }

  Future<void> _loadPricingTiers() async {
    pricingState = ProductPricingState(loading: true);
    final (tiers, _) =
        await ref.read(loadPricingTiersUseCaseProvider).call(editingId!);
    pricingState = ProductPricingState(tiers: tiers);
    _notify();
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
    invalidateProductLists(ref);
    return null;
  }

  Future<void> deleteProduct() async {
    if (editingId == null) return;
    await ref.read(deleteProductUseCaseProvider).call(editingId!);
    startNew();
    invalidateProductLists(ref);
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
    invalidateProductLists(ref);
    return null;
  }

  // Uploads bytes to storage, then records the returned public URL as an image.
  // First image on a product becomes primary.
  Future<InventoryFailure?> uploadImage(Uint8List bytes, String ext) async {
    final id = editingId;
    if (id == null) return null;
    final (url, failure) =
        await ref.read(uploadProductImageUseCaseProvider).call(id, bytes, ext);
    if (failure != null) return failure;
    final addFailure = await addImage({
      'product_id': id,
      'url': url,
      'sort_order': imagesState.images.length,
      'is_primary': imagesState.images.isEmpty,
    });
    invalidateProductLists(ref);
    return addFailure;
  }

  Future<void> setPrimaryImage(String imageId) async {
    await ref.read(setPrimaryImageUseCaseProvider).call(imageId);
    await _loadImages();
    invalidateProductLists(ref);
  }

  Future<void> deleteImage(String id) async {
    await ref.read(deleteImageUseCaseProvider).call(id);
    await _loadImages();
    invalidateProductLists(ref);
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
