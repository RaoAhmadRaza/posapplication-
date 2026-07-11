import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/purchase_order.dart';
import '../entities/purchase_order_item.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class LoadPurchaseOrder {
  final PurchasingRepository _repo;
  LoadPurchaseOrder(this._repo);

  Future<(PurchaseOrder?, List<PurchaseOrderItem>, PurchaseFailure?)> call(
      String id) {
    return _repo.loadPurchaseOrder(id);
  }
}

final loadPurchaseOrderUseCaseProvider = Provider<LoadPurchaseOrder>((ref) {
  return LoadPurchaseOrder(ref.read(purchasingRepositoryProvider));
});
