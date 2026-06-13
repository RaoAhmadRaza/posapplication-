import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class SetDefaultWarehouse {
  final InventoryRepository _repo;
  SetDefaultWarehouse(this._repo);

  Future<(bool, InventoryFailure?)> call(String id) async {
    return _repo.setDefaultWarehouse(id);
  }
}

final setDefaultWarehouseUseCaseProvider = Provider<SetDefaultWarehouse>((ref) {
  return SetDefaultWarehouse(ref.read(inventoryRepositoryProvider));
});
