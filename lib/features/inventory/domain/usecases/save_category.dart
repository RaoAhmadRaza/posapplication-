import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/category.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class SaveCategory {
  final InventoryRepository _repo;
  SaveCategory(this._repo);

  Future<(Category?, InventoryFailure?)> call({
    required Map<String, dynamic> data,
    String? id,
  }) async {
    if (id != null) {
      return _repo.updateCategory(id, data);
    }
    return _repo.createCategory(data);
  }
}

final saveCategoryUseCaseProvider = Provider<SaveCategory>((ref) {
  return SaveCategory(ref.read(inventoryRepositoryProvider));
});
