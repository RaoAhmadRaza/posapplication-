import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_adjustment.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadAdjustments {
  final InventoryRepository _repo;
  LoadAdjustments(this._repo);

  Future<(List<StockAdjustment>, InventoryFailure?)> call({
    String? branchId,
    bool pendingOnly = false,
  }) async {
    return _repo.loadAdjustments(branchId: branchId, pendingOnly: pendingOnly);
  }
}

final loadAdjustmentsUseCaseProvider = Provider<LoadAdjustments>((ref) {
  return LoadAdjustments(ref.read(inventoryRepositoryProvider));
});
