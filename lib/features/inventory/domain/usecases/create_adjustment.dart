import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_adjustment.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../data/repositories/inventory_repository_impl.dart';
import '../../domain/repositories/inventory_repository.dart';

class CreateAdjustment {
  final InventoryRepository _repo;
  CreateAdjustment(this._repo);

  Future<(StockAdjustment?, InventoryFailure?)> call({
    required String branchId,
    required String? warehouseId,
    required String productId,
    required String? variantId,
    required double adjQty,
    required double costPerUnit,
    required String reasonCode,
    String? notes,
  }) async {
    return _repo.createAdjustment(
      branchId: branchId,
      warehouseId: warehouseId,
      productId: productId,
      variantId: variantId,
      adjQty: adjQty,
      costPerUnit: costPerUnit,
      reasonCode: reasonCode,
      notes: notes,
    );
  }
}

final createAdjustmentUseCaseProvider = Provider<CreateAdjustment>((ref) {
  return CreateAdjustment(ref.read(inventoryRepositoryProvider));
});
