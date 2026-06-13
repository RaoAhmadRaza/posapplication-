import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class UpdateWarehouse {
  final InventoryRepository _repo;
  UpdateWarehouse(this._repo);

  Future<(Warehouse?, InventoryFailure?)> call(String id, Map<String, dynamic> data) async {
    return _repo.updateWarehouse(id, data);
  }
}

final updateWarehouseUseCaseProvider = Provider<UpdateWarehouse>((ref) {
  return UpdateWarehouse(ref.read(inventoryRepositoryProvider));
});
