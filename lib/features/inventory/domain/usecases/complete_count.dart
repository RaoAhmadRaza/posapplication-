import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class CompleteCount {
  final InventoryRepository _repo;
  CompleteCount(this._repo);

  Future<(bool, InventoryFailure?)> call(String id) async {
    return _repo.completeCount(id);
  }
}

final completeCountUseCaseProvider = Provider<CompleteCount>((ref) {
  return CompleteCount(ref.read(inventoryRepositoryProvider));
});
