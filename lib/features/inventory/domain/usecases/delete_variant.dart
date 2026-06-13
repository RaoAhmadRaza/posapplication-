import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class DeleteVariant {
  final InventoryRepository _repo;
  DeleteVariant(this._repo);

  Future<(bool, InventoryFailure?)> call(String id) async {
    return _repo.deleteVariant(id);
  }
}

final deleteVariantUseCaseProvider = Provider<DeleteVariant>((ref) {
  return DeleteVariant(ref.read(inventoryRepositoryProvider));
});
