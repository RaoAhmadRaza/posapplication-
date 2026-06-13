import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/warehouse.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadWarehouses {
  final InventoryRepository _repo;
  LoadWarehouses(this._repo);

  Future<(List<Warehouse>, InventoryFailure?)> call({String? branchId}) async {
    return _repo.loadWarehouses(branchId: branchId);
  }
}

final loadWarehousesUseCaseProvider = Provider<LoadWarehouses>((ref) {
  return LoadWarehouses(ref.read(inventoryRepositoryProvider));
});
