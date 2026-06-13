import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class EnsureDefaultWarehouse {
  final InventoryRepository _repo;
  EnsureDefaultWarehouse(this._repo);

  Future<(Warehouse?, InventoryFailure?)> call(String branchId) async {
    return _repo.ensureDefaultWarehouse(branchId);
  }
}

final ensureDefaultWarehouseUseCaseProvider = Provider<EnsureDefaultWarehouse>((ref) {
  return EnsureDefaultWarehouse(ref.read(inventoryRepositoryProvider));
});
