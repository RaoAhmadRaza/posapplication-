import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/purchase_results.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class UpdatePurchaseOrder {
  final PurchasingRepository _repo;
  UpdatePurchaseOrder(this._repo);

  Future<(PoCreateResult?, PurchaseFailure?)> call(
      String id, Map<String, dynamic> data) {
    return _repo.updatePurchaseOrder(id, data);
  }
}

final updatePurchaseOrderUseCaseProvider =
    Provider<UpdatePurchaseOrder>((ref) {
  return UpdatePurchaseOrder(ref.read(purchasingRepositoryProvider));
});
