import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_level.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadStockLevels {
  final InventoryRepository _repo;
  LoadStockLevels(this._repo);

  Future<(List<StockLevel>, InventoryFailure?)> call({
    String? branchId,
    String? warehouseId,
  }) async {
    return _repo.loadStockLevels(branchId: branchId, warehouseId: warehouseId);
  }
}

final loadStockLevelsUseCaseProvider = Provider<LoadStockLevels>((ref) {
  return LoadStockLevels(ref.read(inventoryRepositoryProvider));
});
