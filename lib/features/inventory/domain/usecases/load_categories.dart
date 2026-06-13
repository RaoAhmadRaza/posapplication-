import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/category.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadCategories {
  final InventoryRepository _repo;
  LoadCategories(this._repo);

  Future<(List<Category>, InventoryFailure?)> call() async {
    return _repo.loadCategories();
  }
}

final loadCategoriesUseCaseProvider = Provider<LoadCategories>((ref) {
  return LoadCategories(ref.read(inventoryRepositoryProvider));
});
