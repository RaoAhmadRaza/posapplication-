import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class ApproveAdjustment {
  final InventoryRepository _repo;
  ApproveAdjustment(this._repo);

  Future<(bool, InventoryFailure?)> call(String id) async {
    return _repo.approveAdjustment(id);
  }
}

final approveAdjustmentUseCaseProvider = Provider<ApproveAdjustment>((ref) {
  return ApproveAdjustment(ref.read(inventoryRepositoryProvider));
});
