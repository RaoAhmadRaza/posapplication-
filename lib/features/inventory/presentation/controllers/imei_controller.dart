import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/imei_record.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/load_imei.dart';
import '../../domain/usecases/register_imei.dart';
import 'stock_levels_controller.dart';

final imeiProvider =
    AsyncNotifierProvider<ImeiController, List<ImeiRecord>>(
  ImeiController.new,
);

class ImeiController extends AsyncNotifier<List<ImeiRecord>> {

  @override
  Future<List<ImeiRecord>> build() async {
    final (records, failure) = await ref.read(loadImeiUseCaseProvider).call();
    if (failure != null) throw failure;
    return records;
  }

  Future<void> load({String? productId, String? status}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (records, failure) = await ref
          .read(loadImeiUseCaseProvider)
          .call(productId: productId, status: status);
      if (failure != null) throw failure;
      return records;
    });
  }

  Future<InventoryFailure?> register({
    required String productId,
    required String? variantId,
    required String branchId,
    required String? warehouseId,
    required String imei,
    required String sourceType,
    required double costPrice,
    bool postStock = true,
  }) async {
    final (_, failure) = await ref.read(registerImeiUseCaseProvider).call(
          productId: productId,
          variantId: variantId,
          branchId: branchId,
          warehouseId: warehouseId,
          imei: imei,
          sourceType: sourceType,
          costPrice: costPrice,
          postStock: postStock,
        );
    if (failure != null) return failure;
    ref.invalidateSelf();
    if (postStock) ref.invalidate(stockLevelsProvider);
    return null;
  }
}
