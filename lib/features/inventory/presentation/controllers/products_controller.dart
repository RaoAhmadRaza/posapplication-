import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/product.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/bulk_import_products.dart';
import '../../domain/usecases/load_products.dart';
import '../../domain/usecases/load_products_stock.dart';
import '../../domain/usecases/search_products.dart';
import '../../../sales/presentation/controllers/pos_products_controller.dart';

final productsProvider =
    AsyncNotifierProvider<ProductsController, List<Product>>(
  ProductsController.new,
);

/// The product list exists as two independent controller instances: the
/// inventory catalog and POS ([posProductsProvider]). Every write has to
/// refresh both — invalidating only [productsProvider] leaves the POS grid
/// serving a stale list that is missing the new or edited product.
void invalidateProductLists(Ref ref) {
  ref.invalidate(productsProvider);
  ref.invalidate(posProductsProvider);
}

class ProductsController extends AsyncNotifier<List<Product>> {
  static const _pageSize = 200;
  int _page = 0;
  bool _hasMore = false;
  bool _isSearching = false;
  List<String>? _curCats;
  List<String>? _curBrands;
  List<String>? _curStatuses;

  /// True only in the paginated browse path (not while searching).
  bool get hasMore => _hasMore && !_isSearching;

  @override
  Future<List<Product>> build() async {
    final branch = ref.watch(currentBranchProvider);
    _page = 0;
    _isSearching = false;
    _curCats = _curBrands = _curStatuses = null;
    final (products, failure) =
        await ref.read(loadProductsUseCaseProvider).call(pageSize: _pageSize);
    if (failure != null) throw failure;
    _hasMore = products.length == _pageSize;
    if (branch == null) return products;
    return _mergeStock(products, branch.id);
  }

  void refresh() => ref.invalidateSelf();

  Future<void> load({
    List<String>? categoryIds,
    List<String>? brandIds,
    List<String>? statuses,
  }) async {
    _query(categoryIds: categoryIds, brandIds: brandIds, statuses: statuses);
  }

  Future<void> search(
    String q, {
    List<String>? categoryIds,
    List<String>? brandIds,
    List<String>? statuses,
  }) async {
    _query(
        q: q,
        categoryIds: categoryIds,
        brandIds: brandIds,
        statuses: statuses);
  }

  Future<void> _query({
    String? q,
    List<String>? categoryIds,
    List<String>? brandIds,
    List<String>? statuses,
  }) async {
    _page = 0;
    _isSearching = q != null && q.trim().isNotEmpty;
    _curCats = categoryIds;
    _curBrands = brandIds;
    _curStatuses = statuses;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final branch = ref.read(currentBranchProvider);
      final (results, failure) = _isSearching
          ? await ref.read(searchProductsUseCaseProvider).call(
                q!.trim(),
                categoryIds: categoryIds,
                brandIds: brandIds,
                statuses: statuses,
              )
          : await ref.read(loadProductsUseCaseProvider).call(
                categoryIds: categoryIds,
                brandIds: brandIds,
                statuses: statuses,
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
          categoryIds: _curCats,
          brandIds: _curBrands,
          statuses: _curStatuses,
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
    invalidateProductLists(ref);
    return result;
  }
}
