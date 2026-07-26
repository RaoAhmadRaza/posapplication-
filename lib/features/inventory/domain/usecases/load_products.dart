import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadProducts {
  final InventoryRepository _repo;
  LoadProducts(this._repo);

  Future<(List<Product>, InventoryFailure?)> call({
    List<String>? categoryIds,
    List<String>? brandIds,
    List<String>? statuses,
    int page = 0,
    int pageSize = 200,
  }) async {
    return _repo.loadProducts(
      categoryIds: categoryIds,
      brandIds: brandIds,
      statuses: statuses,
      page: page,
      pageSize: pageSize,
    );
  }
}

final loadProductsUseCaseProvider = Provider<LoadProducts>((ref) {
  return LoadProducts(ref.read(inventoryRepositoryProvider));
});
