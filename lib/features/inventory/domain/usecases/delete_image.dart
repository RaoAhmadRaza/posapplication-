import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class DeleteImage {
  final InventoryRepository _repo;
  DeleteImage(this._repo);

  Future<(bool, InventoryFailure?)> call(String id) async {
    return _repo.deleteImage(id);
  }
}

final deleteImageUseCaseProvider = Provider<DeleteImage>((ref) {
  return DeleteImage(ref.read(inventoryRepositoryProvider));
});
