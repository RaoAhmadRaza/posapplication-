import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class CreateWarehouse {
  final InventoryRepository _repo;
  CreateWarehouse(this._repo);

  Future<(Warehouse?, InventoryFailure?)> call(Map<String, dynamic> data) async {
    return _repo.createWarehouse(data);
  }
}

final createWarehouseUseCaseProvider = Provider<CreateWarehouse>((ref) {
  return CreateWarehouse(ref.read(inventoryRepositoryProvider));
});
