import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/purchase_results.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class SubmitPo {
  final PurchasingRepository _repo;
  SubmitPo(this._repo);

  Future<(PoStatusResult?, PurchaseFailure?)> call(String id) {
    return _repo.submitPurchaseOrder(id);
  }
}

final submitPoUseCaseProvider = Provider<SubmitPo>((ref) {
  return SubmitPo(ref.read(purchasingRepositoryProvider));
});
