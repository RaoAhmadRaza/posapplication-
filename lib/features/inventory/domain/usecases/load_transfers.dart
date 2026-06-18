import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadTransfers {
  final InventoryRepository _repo;
  LoadTransfers(this._repo);

  Future<(List<StockTransfer>, InventoryFailure?)> call({
    String? branchId,
    String? direction,
  }) async {
    return _repo.loadTransfers(branchId: branchId, direction: direction);
  }
}

final loadTransfersUseCaseProvider = Provider<LoadTransfers>((ref) {
  return LoadTransfers(ref.read(inventoryRepositoryProvider));
});
