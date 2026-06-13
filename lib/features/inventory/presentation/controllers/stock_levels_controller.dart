import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/stock_level.dart';
import '../../domain/usecases/ensure_default_warehouse.dart';
import '../../domain/usecases/load_stock_levels.dart';

final stockLevelsProvider =
    AsyncNotifierProvider<StockLevelsController, List<StockLevel>>(
  StockLevelsController.new,
);

class StockLevelsController extends AsyncNotifier<List<StockLevel>> {
  @override
  Future<List<StockLevel>> build() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return <StockLevel>[];

    final (wh, _) =
        await ref.read(ensureDefaultWarehouseUseCaseProvider).call(branch.id);
    final defaultWarehouseId = wh?.id;

    final (levels, failure) = await ref
        .read(loadStockLevelsUseCaseProvider)
        .call(branchId: branch.id, warehouseId: defaultWarehouseId);
    if (failure != null) throw failure;
    return levels;
  }

  Future<void> load({String? warehouseId}) async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (levels, failure) = await ref
          .read(loadStockLevelsUseCaseProvider)
          .call(branchId: branch.id, warehouseId: warehouseId);
      if (failure != null) throw failure;
      return levels;
    });
  }
}
