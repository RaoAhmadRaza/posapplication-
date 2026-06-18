import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/stock_adjustment.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/load_adjustments.dart';
import '../../domain/usecases/create_adjustment.dart';
import '../../domain/usecases/approve_adjustment.dart';
import 'stock_levels_controller.dart';

final adjustmentsProvider =
    AsyncNotifierProvider<AdjustmentsController, List<StockAdjustment>>(
  AdjustmentsController.new,
);

class AdjustmentsController extends AsyncNotifier<List<StockAdjustment>> {
  @override
  Future<List<StockAdjustment>> build() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return <StockAdjustment>[];
    final (adjustments, failure) = await ref
        .read(loadAdjustmentsUseCaseProvider)
        .call(branchId: branch.id);
    if (failure != null) throw failure;
    return adjustments;
  }

  Future<(StockAdjustment?, InventoryFailure?)> create({
    required String branchId,
    required String? warehouseId,
    required String productId,
    required String? variantId,
    required double adjQty,
    required double costPerUnit,
    required String reasonCode,
    String? notes,
  }) async {
    final result = await ref.read(createAdjustmentUseCaseProvider).call(
          branchId: branchId,
          warehouseId: warehouseId,
          productId: productId,
          variantId: variantId,
          adjQty: adjQty,
          costPerUnit: costPerUnit,
          reasonCode: reasonCode,
          notes: notes,
        );
    if (result.$2 != null) return (null, result.$2);
    ref.invalidateSelf();
    ref.invalidate(stockLevelsProvider);
    return result;
  }

  Future<void> approve(String id) async {
    final (_, failure) =
        await ref.read(approveAdjustmentUseCaseProvider).call(id);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
      return;
    }
    ref.invalidateSelf();
    ref.invalidate(stockLevelsProvider);
  }
}
