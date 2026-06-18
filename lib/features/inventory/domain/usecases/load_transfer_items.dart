import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_transfer_item.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadTransferItems {
  final InventoryRepository _repo;
  LoadTransferItems(this._repo);

  Future<(List<StockTransferItem>, InventoryFailure?)> call(String transferId) async {
    return _repo.loadTransferItems(transferId);
  }
}

final loadTransferItemsUseCaseProvider = Provider<LoadTransferItems>((ref) {
  return LoadTransferItems(ref.read(inventoryRepositoryProvider));
});
