import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/brand.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class SaveBrand {
  final InventoryRepository _repo;
  SaveBrand(this._repo);

  Future<(Brand?, InventoryFailure?)> call({
    required Map<String, dynamic> data,
    String? id,
  }) async {
    if (id != null) {
      return _repo.updateBrand(id, data);
    }
    return _repo.createBrand(data);
  }
}

final saveBrandUseCaseProvider = Provider<SaveBrand>((ref) {
  return SaveBrand(ref.read(inventoryRepositoryProvider));
});
