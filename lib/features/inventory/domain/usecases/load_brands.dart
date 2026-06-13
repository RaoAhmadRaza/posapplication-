import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/brand.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadBrands {
  final InventoryRepository _repo;
  LoadBrands(this._repo);

  Future<(List<Brand>, InventoryFailure?)> call() async {
    return _repo.loadBrands();
  }
}

final loadBrandsUseCaseProvider = Provider<LoadBrands>((ref) {
  return LoadBrands(ref.read(inventoryRepositoryProvider));
});
