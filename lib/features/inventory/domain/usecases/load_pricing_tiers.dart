import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/pricing_tier.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadPricingTiers {
  final InventoryRepository _repo;
  LoadPricingTiers(this._repo);

  Future<(List<PricingTier>, InventoryFailure?)> call(String productId) async {
    return _repo.loadPricingTiers(productId);
  }
}

final loadPricingTiersUseCaseProvider = Provider<LoadPricingTiers>((ref) {
  return LoadPricingTiers(ref.read(inventoryRepositoryProvider));
});
