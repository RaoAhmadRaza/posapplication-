import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class SetPrimaryImage {
  final InventoryRepository _repo;
  SetPrimaryImage(this._repo);

  Future<(bool, InventoryFailure?)> call(String imageId) async {
    return _repo.setPrimaryImage(imageId);
  }
}

final setPrimaryImageUseCaseProvider = Provider<SetPrimaryImage>((ref) {
  return SetPrimaryImage(ref.read(inventoryRepositoryProvider));
});
