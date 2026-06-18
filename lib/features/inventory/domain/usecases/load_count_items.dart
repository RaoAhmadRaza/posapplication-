import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_count_item.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadCountItems {
  final InventoryRepository _repo;
  LoadCountItems(this._repo);

  Future<(List<StockCountItem>, InventoryFailure?)> call(String countId) async {
    return _repo.loadCountItems(countId);
  }
}

final loadCountItemsUseCaseProvider = Provider<LoadCountItems>((ref) {
  return LoadCountItems(ref.read(inventoryRepositoryProvider));
});
