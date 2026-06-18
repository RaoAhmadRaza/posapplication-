import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class ReceiveTransfer {
  final InventoryRepository _repo;
  ReceiveTransfer(this._repo);

  Future<(bool, InventoryFailure?)> call(String id, List<Map<String, dynamic>> received) async {
    return _repo.receiveTransfer(id, received);
  }
}

final receiveTransferUseCaseProvider = Provider<ReceiveTransfer>((ref) {
  return ReceiveTransfer(ref.read(inventoryRepositoryProvider));
});
