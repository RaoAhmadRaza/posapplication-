import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class DeleteBrand {
  final InventoryRepository _repo;
  DeleteBrand(this._repo);

  Future<(bool, InventoryFailure?)> call(String id) async {
    return _repo.deleteBrand(id);
  }
}

final deleteBrandUseCaseProvider = Provider<DeleteBrand>((ref) {
  return DeleteBrand(ref.read(inventoryRepositoryProvider));
});
