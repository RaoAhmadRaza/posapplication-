import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadProductsStock {
  final InventoryRepository _repo;
  LoadProductsStock(this._repo);

  Future<(Map<String, double>, InventoryFailure?)> call({
    required String branchId,
  }) async {
    return _repo.loadProductsStock(branchId: branchId);
  }
}

final loadProductsStockUseCaseProvider = Provider<LoadProductsStock>((ref) {
  return LoadProductsStock(ref.read(inventoryRepositoryProvider));
});
