import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/stock_transfer.dart';
import '../../domain/failures/inventory_failure.dart';
import '../../domain/usecases/load_transfers.dart';
import '../../domain/usecases/create_transfer.dart';
import '../../domain/usecases/dispatch_transfer.dart';
import '../../domain/usecases/receive_transfer.dart';
import '../../domain/usecases/cancel_transfer.dart';
import 'stock_levels_controller.dart';

final transfersProvider =
    AsyncNotifierProvider<TransfersController, List<StockTransfer>>(
  TransfersController.new,
);

class TransfersController extends AsyncNotifier<List<StockTransfer>> {
  @override
  Future<List<StockTransfer>> build() async {
    final branch = ref.read(currentBranchProvider);
    if (branch == null) return <StockTransfer>[];
    final (transfers, failure) = await ref
        .read(loadTransfersUseCaseProvider)
        .call(branchId: branch.id);
    if (failure != null) throw failure;
    return transfers;
  }

  Future<InventoryFailure?> create({
    required String fromBranchId,
    required String toBranchId,
    required String? fromWarehouseId,
    required String? toWarehouseId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final (_, failure) = await ref.read(createTransferUseCaseProvider).call(
          fromBranchId: fromBranchId,
          toBranchId: toBranchId,
          fromWarehouseId: fromWarehouseId,
          toWarehouseId: toWarehouseId,
          items: items,
          notes: notes,
        );
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }

  Future<void> dispatch(String id) async {
    final (_, failure) =
        await ref.read(dispatchTransferUseCaseProvider).call(id);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
      return;
    }
    ref.invalidateSelf();
    ref.invalidate(stockLevelsProvider);
  }

  Future<void> receive(String id, List<Map<String, dynamic>> received) async {
    final (_, failure) =
        await ref.read(receiveTransferUseCaseProvider).call(id, received);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
      return;
    }
    ref.invalidateSelf();
    ref.invalidate(stockLevelsProvider);
  }

  Future<void> cancel(String id) async {
    final (_, failure) =
        await ref.read(cancelTransferUseCaseProvider).call(id);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
      return;
    }
    ref.invalidateSelf();
    ref.invalidate(stockLevelsProvider);
  }
}
