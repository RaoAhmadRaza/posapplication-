import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class CreateTransfer {
  final InventoryRepository _repo;
  CreateTransfer(this._repo);

  Future<(StockTransfer?, InventoryFailure?)> call({
    required String fromBranchId,
    required String toBranchId,
    required String? fromWarehouseId,
    required String? toWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    return _repo.createTransfer(
      fromBranchId: fromBranchId,
      toBranchId: toBranchId,
      fromWarehouseId: fromWarehouseId,
      toWarehouseId: toWarehouseId,
      items: items,
      notes: notes,
    );
  }
}

final createTransferUseCaseProvider = Provider<CreateTransfer>((ref) {
  return CreateTransfer(ref.read(inventoryRepositoryProvider));
});
