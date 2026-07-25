import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/product.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/bulk_import_products.dart';
import '../../domain/usecases/load_products.dart';
import '../../domain/usecases/load_products_stock.dart';
import '../../domain/usecases/search_products.dart';

final productsProvider =
    AsyncNotifierProvider<ProductsController, List<Product>>(
  ProductsController.new,
);

class ProductsController extends AsyncNotifier<List<Product>> {
  static const _pageSize = 200;
  int _page = 0;
  bool _hasMore = false;
  bool _isSearching = false;
  String? _curCat;
  String? _curBrand;
  String? _curStatus;

  /// True only in the paginated browse path (not while searching).
  bool get hasMore => _hasMore && !_isSearching;

  @override
  Future<List<Product>> build() async {
    final branch = ref.watch(currentBranchProvider);
    _page = 0;
    _isSearching = false;
    _curCat = _curBrand = _curStatus = null;
    final (products, failure) =
        await ref.read(loadProductsUseCaseProvider).call(pageSize: _pageSize);
    if (failure != null) throw failure;
    _hasMore = products.length == _pageSize;
    if (branch == null) return products;
    return _mergeStock(products, branch.id);
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
    _page = 0;
    _isSearching = q != null && q.trim().isNotEmpty;
    _curCat = categoryId;
    _curBrand = brandId;
    _curStatus = status;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final branch = ref.read(currentBranchProvider);
      final (results, failure) = _isSearching
          ? await ref.read(searchProductsUseCaseProvider).call(
                q!.trim(),
                categoryId: categoryId,
                brandId: brandId,
                status: status,
              )
          : await ref.read(loadProductsUseCaseProvider).call(
                categoryId: categoryId,
                brandId: brandId,
                status: status,
                pageSize: _pageSize,
              );
      if (failure != null) throw failure;
      _hasMore = !_isSearching && results.length == _pageSize;
      if (branch == null) return results;
      return _mergeStock(results, branch.id);
    });
  }

  /// Appends the next page in the browse path. No-op while searching or when
  /// the last page was short. Returns a failure (list kept intact) so the page
  /// can surface it instead of swallowing.
  Future<InventoryFailure?> loadMore() async {
    if (_isSearching || !_hasMore) return null;
    final next = _page + 1;
    final (rows, failure) = await ref.read(loadProductsUseCaseProvider).call(
          categoryId: _curCat,
          brandId: _curBrand,
          status: _curStatus,
          page: next,
          pageSize: _pageSize,
        );
    if (failure != null) return failure;
    _page = next;
    _hasMore = rows.length == _pageSize;
    final branch = ref.read(currentBranchProvider);
    final merged = branch == null ? rows : await _mergeStock(rows, branch.id);
    final current = state.value ?? const <Product>[];
    // Defence-in-depth against any residual page overlap: never append an id
    // already in the list (seen.add is false when the id is already present).
    final seen = current.map((p) => p.id).toSet();
    final fresh = merged.where((p) => seen.add(p.id)).toList();
    state = AsyncValue.data([...current, ...fresh]);
    return null;
  }

  Future<List<Product>> _mergeStock(List<Product> products, String branchId) async {
    final (stockMap, stockFailure) = await ref
        .read(loadProductsStockUseCaseProvider)
        .call(branchId: branchId);
    if (stockFailure != null) throw stockFailure;
    return products.map((p) => p.copyWith(qtyOnHand: stockMap[p.id])).toList();
  }

  Future<Map<String, dynamic>?> bulkImport(List<Map<String, dynamic>> rows) async {
    final (result, failure) =
        await ref.read(bulkImportProductsUseCaseProvider).call(rows);
    if (failure != null) return null;
    ref.invalidateSelf();
    return result;
  }
}
