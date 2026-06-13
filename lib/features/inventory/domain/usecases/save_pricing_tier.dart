import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/pricing_tier.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class SavePricingTier {
  final InventoryRepository _repo;
  SavePricingTier(this._repo);

  Future<(PricingTier?, InventoryFailure?)> call({
    required Map<String, dynamic> data,
    String? id,
  }) async {
    if (id != null) {
      return _repo.updatePricingTier(id, data);
    }
    return _repo.createPricingTier(data);
  }
}

final savePricingTierUseCaseProvider = Provider<SavePricingTier>((ref) {
  return SavePricingTier(ref.read(inventoryRepositoryProvider));
});
