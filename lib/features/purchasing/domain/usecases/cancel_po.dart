import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/purchase_results.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class CancelPo {
  final PurchasingRepository _repo;
  CancelPo(this._repo);

  Future<(PoStatusResult?, PurchaseFailure?)> call(String id, String? reason) {
    return _repo.cancelPurchaseOrder(id, reason);
  }
}

final cancelPoUseCaseProvider = Provider<CancelPo>((ref) {
  return CancelPo(ref.read(purchasingRepositoryProvider));
});
