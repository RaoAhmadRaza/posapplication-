import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class DeleteProduct {
  final InventoryRepository _repo;
  DeleteProduct(this._repo);

  Future<(bool, InventoryFailure?)> call(String id) async {
    return _repo.deleteProduct(id);
  }
}

final deleteProductUseCaseProvider = Provider<DeleteProduct>((ref) {
  return DeleteProduct(ref.read(inventoryRepositoryProvider));
});
