import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadVariants {
  final InventoryRepository _repo;
  LoadVariants(this._repo);

  Future<(List<ProductVariant>, InventoryFailure?)> call(String productId) async {
    return _repo.loadVariants(productId);
  }
}

final loadVariantsUseCaseProvider = Provider<LoadVariants>((ref) {
  return LoadVariants(ref.read(inventoryRepositoryProvider));
});
