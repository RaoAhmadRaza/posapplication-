import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/purchase_order.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class LoadPurchaseOrders {
  final PurchasingRepository _repo;
  LoadPurchaseOrders(this._repo);

  Future<(List<PurchaseOrder>, PurchaseFailure?)> call({
    PurchaseOrderStatus? status,
  }) {
    return _repo.loadPurchaseOrders(status: status);
  }
}

final loadPurchaseOrdersUseCaseProvider =
    Provider<LoadPurchaseOrders>((ref) {
  return LoadPurchaseOrders(ref.read(purchasingRepositoryProvider));
});
