import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class DeleteCategory {
  final InventoryRepository _repo;
  DeleteCategory(this._repo);

  Future<(bool, InventoryFailure?)> call(String id) async {
    return _repo.deleteCategory(id);
  }
}

final deleteCategoryUseCaseProvider = Provider<DeleteCategory>((ref) {
  return DeleteCategory(ref.read(inventoryRepositoryProvider));
});
