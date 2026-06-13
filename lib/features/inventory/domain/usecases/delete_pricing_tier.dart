import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class DeletePricingTier {
  final InventoryRepository _repo;
  DeletePricingTier(this._repo);

  Future<(bool, InventoryFailure?)> call(String id) async {
    return _repo.deletePricingTier(id);
  }
}

final deletePricingTierUseCaseProvider = Provider<DeletePricingTier>((ref) {
  return DeletePricingTier(ref.read(inventoryRepositoryProvider));
});
