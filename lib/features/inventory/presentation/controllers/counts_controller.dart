import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/stock_count.dart';
import '../../domain/usecases/load_counts.dart';
import '../../domain/usecases/open_count.dart';
import '../../domain/usecases/record_count_item.dart';
import '../../domain/usecases/complete_count.dart';
import 'stock_levels_controller.dart';

final countsProvider =
    AsyncNotifierProvider<CountsController, List<StockCount>>(
  CountsController.new,
);

class CountsController extends AsyncNotifier<List<StockCount>> {
  @override
  Future<List<StockCount>> build() async {
    final (counts, failure) = await ref.read(loadCountsUseCaseProvider).call();
    if (failure != null) throw failure;
    return counts;
  }

  Future<StockCount?> open({
    required String branchId,
    String? warehouseId,
    String? categoryId,
  }) async {
    final (count, failure) = await ref.read(openCountUseCaseProvider).call(
          branchId: branchId,
          warehouseId: warehouseId,
          categoryId: categoryId,
        );
    if (failure != null) throw failure;
    ref.invalidateSelf();
    return count;
  }

  Future<void> recordItem(String itemId, double counted) async {
    final (_, failure) =
        await ref.read(recordCountItemUseCaseProvider).call(itemId, counted);
    if (failure != null) {
      throw failure;
    }
    ref.invalidateSelf();
  }

  Future<void> complete(String id) async {
    final (_, failure) =
        await ref.read(completeCountUseCaseProvider).call(id);
    if (failure != null) {
      throw failure;
    }
    ref.invalidateSelf();
    ref.invalidate(stockLevelsProvider);
  }
}
