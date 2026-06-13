import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product_variant.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class SaveVariant {
  final InventoryRepository _repo;
  SaveVariant(this._repo);

  Future<(ProductVariant?, InventoryFailure?)> call({
    required Map<String, dynamic> data,
    String? id,
  }) async {
    if (id != null) {
      return _repo.updateVariant(id, data);
    }
    return _repo.createVariant(data);
  }
}

final saveVariantUseCaseProvider = Provider<SaveVariant>((ref) {
  return SaveVariant(ref.read(inventoryRepositoryProvider));
});
