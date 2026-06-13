import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_ledger_entry.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadProductLedger {
  final InventoryRepository _repo;
  LoadProductLedger(this._repo);

  Future<(List<StockLedgerEntry>, InventoryFailure?)> call(
    String productId, {
    String? branchId,
    String? warehouseId,
  }) async {
    return _repo.loadProductLedger(
      productId,
      branchId: branchId,
      warehouseId: warehouseId,
    );
  }
}

final loadProductLedgerUseCaseProvider = Provider<LoadProductLedger>((ref) {
  return LoadProductLedger(ref.read(inventoryRepositoryProvider));
});
