import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class DeleteWarehouse {
  final InventoryRepository _repo;
  DeleteWarehouse(this._repo);

  Future<(bool, InventoryFailure?)> call(String id) async {
    return _repo.deleteWarehouse(id);
  }
}

final deleteWarehouseUseCaseProvider = Provider<DeleteWarehouse>((ref) {
  return DeleteWarehouse(ref.read(inventoryRepositoryProvider));
});
