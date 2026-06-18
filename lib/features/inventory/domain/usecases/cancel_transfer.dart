import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class CancelTransfer {
  final InventoryRepository _repo;
  CancelTransfer(this._repo);

  Future<(bool, InventoryFailure?)> call(String id) async {
    return _repo.cancelTransfer(id);
  }
}

final cancelTransferUseCaseProvider = Provider<CancelTransfer>((ref) {
  return CancelTransfer(ref.read(inventoryRepositoryProvider));
});
