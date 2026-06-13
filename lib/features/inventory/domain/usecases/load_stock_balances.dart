import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_balance.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadStockBalances {
  final InventoryRepository _repo;
  LoadStockBalances(this._repo);

  Future<(List<StockBalance>, InventoryFailure?)> call({
    String? branchId,
    String? warehouseId,
    String? productId,
  }) async {
    return _repo.loadStockBalances(
      branchId: branchId,
      warehouseId: warehouseId,
      productId: productId,
    );
  }
}

final loadStockBalancesUseCaseProvider = Provider<LoadStockBalances>((ref) {
  return LoadStockBalances(ref.read(inventoryRepositoryProvider));
});
