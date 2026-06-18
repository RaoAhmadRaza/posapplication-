import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class RecordCountItem {
  final InventoryRepository _repo;
  RecordCountItem(this._repo);

  Future<(bool, InventoryFailure?)> call(String itemId, double counted) async {
    return _repo.recordCountItem(itemId, counted);
  }
}

final recordCountItemUseCaseProvider = Provider<RecordCountItem>((ref) {
  return RecordCountItem(ref.read(inventoryRepositoryProvider));
});
