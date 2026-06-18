import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class DispatchTransfer {
  final InventoryRepository _repo;
  DispatchTransfer(this._repo);

  Future<(bool, InventoryFailure?)> call(String id) async {
    return _repo.dispatchTransfer(id);
  }
}

final dispatchTransferUseCaseProvider = Provider<DispatchTransfer>((ref) {
  return DispatchTransfer(ref.read(inventoryRepositoryProvider));
});
