import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class LoadCounts {
  final InventoryRepository _repo;
  LoadCounts(this._repo);

  Future<(List<StockCount>, InventoryFailure?)> call() async {
    return _repo.loadCounts();
  }
}

final loadCountsUseCaseProvider = Provider<LoadCounts>((ref) {
  return LoadCounts(ref.read(inventoryRepositoryProvider));
});
