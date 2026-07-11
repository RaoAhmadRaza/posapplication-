import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/purchase_return.dart';
import '../../domain/entities/purchase_return_item.dart';
import '../../domain/entities/purchase_results.dart';
import '../../domain/failures/purchase_failure.dart';
import '../../domain/usecases/load_purchase_returns.dart';
import '../../domain/usecases/load_purchase_return.dart';
import '../../domain/usecases/load_returned_qtys_for_po.dart';
import '../../domain/usecases/create_purchase_return.dart';

final purchaseReturnsProvider =
    AsyncNotifierProvider<PurchaseReturnsController, List<PurchaseReturn>>(
  PurchaseReturnsController.new,
);

class PurchaseReturnsController extends AsyncNotifier<List<PurchaseReturn>> {
  PurchaseReturnStatus? _status;

  PurchaseReturnStatus? get statusFilter => _status;

  @override
  Future<List<PurchaseReturn>> build() async {
    final (returns, failure) = await ref
        .read(loadPurchaseReturnsUseCaseProvider)
        .call(status: _status);
    if (failure != null) throw failure;
    return returns;
  }

  Future<void> setStatus(PurchaseReturnStatus? status) async {
    _status = status;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (returns, failure) = await ref
          .read(loadPurchaseReturnsUseCaseProvider)
          .call(status: _status);
      if (failure != null) throw failure;
      return returns;
    });
  }

  void refresh() => ref.invalidateSelf();

  /// Returns the RPC result (voucher number + total) on success, or a failure.
  Future<(ReturnCreateResult?, PurchaseFailure?)> create({
    required String branchId,
    required String poId,
    String? grnId,
    String? invoiceId,
    required String reason,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) async {
    final (result, failure) =
        await ref.read(createPurchaseReturnUseCaseProvider).call(
              branchId: branchId,
              poId: poId,
              grnId: grnId,
              invoiceId: invoiceId,
              reason: reason,
              notes: notes,
              items: items,
            );
    if (failure != null) return (null, failure);
    ref.invalidateSelf();
    return (result, null);
  }
}

/// A single return with its line items for the detail page.
final purchaseReturnDetailProvider = FutureProvider.autoDispose.family<
    ({PurchaseReturn ret, List<PurchaseReturnItem> items}), String>(
  (ref, id) async {
    final (ret, items, failure) =
        await ref.read(loadPurchaseReturnUseCaseProvider).call(id);
    if (failure != null) throw failure;
    return (ret: ret!, items: items);
  },
);

/// Already-returned qty per po_item across CONFIRMED returns of a PO.
final poReturnedQtysProvider =
    FutureProvider.autoDispose.family<Map<String, double>, String>(
  (ref, poId) async {
    final (map, failure) =
        await ref.read(loadReturnedQtysForPoUseCaseProvider).call(poId);
    if (failure != null) throw failure;
    return map;
  },
);
