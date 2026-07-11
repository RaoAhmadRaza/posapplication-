import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/purchase_order.dart';
import '../../domain/entities/purchase_order_item.dart';
import '../../domain/entities/grn.dart';
import '../../domain/usecases/load_purchase_order.dart';
import '../../domain/usecases/load_grns.dart';

/// Loads a single PO with its line items for the detail page.
final purchaseOrderDetailProvider = FutureProvider.autoDispose
    .family<({PurchaseOrder po, List<PurchaseOrderItem> items}), String>(
        (ref, id) async {
  final (po, items, failure) =
      await ref.read(loadPurchaseOrderUseCaseProvider).call(id);
  if (failure != null) throw failure;
  return (po: po!, items: items);
});

/// GRNs recorded against a PO.
final poGrnsProvider =
    FutureProvider.autoDispose.family<List<Grn>, String>((ref, poId) async {
  final (grns, failure) = await ref.read(loadGrnsUseCaseProvider).call(poId);
  if (failure != null) throw failure;
  return grns;
});
