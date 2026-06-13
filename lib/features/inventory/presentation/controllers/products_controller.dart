import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/load_products.dart';
import '../../domain/usecases/search_products.dart';

final productsProvider =
    AsyncNotifierProvider<ProductsController, List<Product>>(
  ProductsController.new,
);

class ProductsController extends AsyncNotifier<List<Product>> {
  @override
  Future<List<Product>> build() async {
    final (products, failure) =
        await ref.read(loadProductsUseCaseProvider).call();
    if (failure != null) throw failure;
    return products;
  }

  void refresh() => ref.invalidateSelf();

  Future<void> load({
    String? categoryId,
    String? brandId,
    String? status,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (products, failure) = await ref.read(loadProductsUseCaseProvider).call(
            categoryId: categoryId,
            brandId: brandId,
            status: status,
          );
      if (failure != null) throw failure;
      return products;
    });
  }

  Future<void> search(String q) async {
    if (q.trim().isEmpty) {
      ref.invalidateSelf();
      return;
    }
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (results, failure) =
          await ref.read(searchProductsUseCaseProvider).call(q.trim());
      if (failure != null) throw failure;
      return results;
    });
  }
}
