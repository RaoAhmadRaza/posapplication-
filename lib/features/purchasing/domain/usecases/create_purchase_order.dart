import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/purchase_results.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class CreatePurchaseOrder {
  final PurchasingRepository _repo;
  CreatePurchaseOrder(this._repo);

  Future<(PoCreateResult?, PurchaseFailure?)> call(
      Map<String, dynamic> data) {
    return _repo.createPurchaseOrder(data);
  }
}

final createPurchaseOrderUseCaseProvider =
    Provider<CreatePurchaseOrder>((ref) {
  return CreatePurchaseOrder(ref.read(purchasingRepositoryProvider));
});
