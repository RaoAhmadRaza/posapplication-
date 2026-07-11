import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/purchase_results.dart';
import '../../domain/failures/purchase_failure.dart';
import '../../domain/usecases/load_purchase_orders.dart';
import '../../domain/usecases/create_purchase_order.dart';
import '../../domain/usecases/update_purchase_order.dart';
import '../../domain/usecases/submit_po.dart';
import '../../domain/usecases/approve_po.dart';
import '../../domain/usecases/cancel_po.dart';
import '../../domain/usecases/receive_goods.dart';

final purchaseOrdersProvider =
    AsyncNotifierProvider<PurchaseOrdersController, List<PurchaseOrder>>(
  PurchaseOrdersController.new,
);

class PurchaseOrdersController extends AsyncNotifier<List<PurchaseOrder>> {
  PurchaseOrderStatus? _status;

  PurchaseOrderStatus? get statusFilter => _status;

  @override
  Future<List<PurchaseOrder>> build() async {
    final (orders, failure) = await ref
        .read(loadPurchaseOrdersUseCaseProvider)
        .call(status: _status);
    if (failure != null) throw failure;
    return orders;
  }

  Future<void> setStatus(PurchaseOrderStatus? status) async {
    _status = status;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (orders, failure) = await ref
          .read(loadPurchaseOrdersUseCaseProvider)
          .call(status: _status);
      if (failure != null) throw failure;
      return orders;
    });
  }

  void refresh() => ref.invalidateSelf();

  Future<PurchaseFailure?> create(Map<String, dynamic> data) async {
    final (_, failure) =
        await ref.read(createPurchaseOrderUseCaseProvider).call(data);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }

  Future<PurchaseFailure?> edit(String id, Map<String, dynamic> data) async {
    final (_, failure) =
        await ref.read(updatePurchaseOrderUseCaseProvider).call(id, data);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }

  Future<PurchaseFailure?> submit(String id) async {
    final (_, failure) = await ref.read(submitPoUseCaseProvider).call(id);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }

  Future<PurchaseFailure?> approve(String id) async {
    final (_, failure) = await ref.read(approvePoUseCaseProvider).call(id);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }

  Future<PurchaseFailure?> cancel(String id, String? reason) async {
    final (_, failure) =
        await ref.read(cancelPoUseCaseProvider).call(id, reason);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }

  /// Returns the GRN result (grn number + new PO status) on success.
  Future<(ReceiveResult?, PurchaseFailure?)> receive({
    required String poId,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final (result, failure) = await ref
        .read(receiveGoodsUseCaseProvider)
        .call(poId: poId, notes: notes, items: items);
    if (failure != null) return (null, failure);
    ref.invalidateSelf();
    return (result, null);
  }
}
