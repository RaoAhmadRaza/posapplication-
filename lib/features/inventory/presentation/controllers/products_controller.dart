import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import '../../domain/usecases/bulk_import_products.dart';
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
    _query(categoryId: categoryId, brandId: brandId, status: status);
  }

  Future<void> search(
    String q, {
    String? categoryId,
    String? brandId,
    String? status,
  }) async {
    _query(q: q, categoryId: categoryId, brandId: brandId, status: status);
  }

  Future<void> _query({
    String? q,
    String? categoryId,
    String? brandId,
    String? status,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final isSearching = q != null && q.trim().isNotEmpty;
      final (results, failure) = isSearching
          ? await ref.read(searchProductsUseCaseProvider).call(
                q.trim(),
                categoryId: categoryId,
                brandId: brandId,
                status: status,
              )
          : await ref.read(loadProductsUseCaseProvider).call(
                categoryId: categoryId,
                brandId: brandId,
                status: status,
              );
      if (failure != null) throw failure;
      return results;
    });
  }

  Future<Map<String, dynamic>?> bulkImport(List<Map<String, dynamic>> rows) async {
    final (result, failure) =
        await ref.read(bulkImportProductsUseCaseProvider).call(rows);
    if (failure != null) return null;
    ref.invalidateSelf();
    return result;
  }
}
