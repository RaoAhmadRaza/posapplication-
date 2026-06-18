import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class OpenCount {
  final InventoryRepository _repo;
  OpenCount(this._repo);

  Future<(StockCount?, InventoryFailure?)> call({
    required String branchId,
    String? warehouseId,
    String? categoryId,
  }) async {
    return _repo.openCount(
      branchId: branchId,
      warehouseId: warehouseId,
      categoryId: categoryId,
    );
  }
}

final openCountUseCaseProvider = Provider<OpenCount>((ref) {
  return OpenCount(ref.read(inventoryRepositoryProvider));
});
