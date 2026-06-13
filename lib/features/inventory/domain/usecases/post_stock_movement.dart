import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_balance.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class PostStockMovement {
  final InventoryRepository _repo;
  PostStockMovement(this._repo);

  Future<(StockBalance?, InventoryFailure?)> call({
    required String branchId,
    required String? warehouseId,
    required String productId,
    required String? variantId,
    required String operationType,
    required double qtyChange,
    required double costPerUnit,
    required String referenceType,
    required String referenceId,
    String? notes,
  }) async {
    return _repo.postStockMovement(
      branchId: branchId,
      warehouseId: warehouseId,
      productId: productId,
      variantId: variantId,
      operationType: operationType,
      qtyChange: qtyChange,
      costPerUnit: costPerUnit,
      referenceType: referenceType,
      referenceId: referenceId,
      notes: notes,
    );
  }
}

final postStockMovementUseCaseProvider = Provider<PostStockMovement>((ref) {
  return PostStockMovement(ref.read(inventoryRepositoryProvider));
});
