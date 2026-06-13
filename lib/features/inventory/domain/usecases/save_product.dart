import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/product.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class SaveProduct {
  final InventoryRepository _repo;
  SaveProduct(this._repo);

  Future<(Product?, InventoryFailure?)> call({
    required Map<String, dynamic> data,
    String? id,
  }) async {
    if (id != null) {
      return _repo.updateProduct(id, data);
    }
    return _repo.createProduct(data);
  }
}

final saveProductUseCaseProvider = Provider<SaveProduct>((ref) {
  return SaveProduct(ref.read(inventoryRepositoryProvider));
});
