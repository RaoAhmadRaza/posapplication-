import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/purchase_return.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class LoadPurchaseReturns {
  final PurchasingRepository _repo;
  LoadPurchaseReturns(this._repo);

  Future<(List<PurchaseReturn>, PurchaseFailure?)> call({
    PurchaseReturnStatus? status,
    String? supplierId,
    String? poId,
  }) {
    return _repo.loadPurchaseReturns(
        status: status, supplierId: supplierId, poId: poId);
  }
}

final loadPurchaseReturnsUseCaseProvider =
    Provider<LoadPurchaseReturns>((ref) {
  return LoadPurchaseReturns(ref.read(purchasingRepositoryProvider));
});
