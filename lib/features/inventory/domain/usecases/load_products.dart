import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadProducts {
  final InventoryRepository _repo;
  LoadProducts(this._repo);

  Future<(List<Product>, InventoryFailure?)> call({
    String? categoryId,
    String? brandId,
    String? status,
    int page = 0,
    int pageSize = 200,
  }) async {
    return _repo.loadProducts(
      categoryId: categoryId,
      brandId: brandId,
      status: status,
      page: page,
      pageSize: pageSize,
    );
  }
}

final loadProductsUseCaseProvider = Provider<LoadProducts>((ref) {
  return LoadProducts(ref.read(inventoryRepositoryProvider));
});
