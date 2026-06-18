import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class UpdateApprovalThreshold {
  final InventoryRepository _repo;
  UpdateApprovalThreshold(this._repo);

  Future<(bool, InventoryFailure?)> call(double value) async {
    return _repo.updateApprovalThreshold(value);
  }
}

final updateApprovalThresholdUseCaseProvider = Provider<UpdateApprovalThreshold>((ref) {
  return UpdateApprovalThreshold(ref.read(inventoryRepositoryProvider));
});
