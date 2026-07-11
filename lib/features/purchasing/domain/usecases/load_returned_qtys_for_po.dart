import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class LoadReturnedQtysForPo {
  final PurchasingRepository _repo;
  LoadReturnedQtysForPo(this._repo);

  Future<(Map<String, double>, PurchaseFailure?)> call(String poId) {
    return _repo.loadReturnedQtysForPo(poId);
  }
}

final loadReturnedQtysForPoUseCaseProvider =
    Provider<LoadReturnedQtysForPo>((ref) {
  return LoadReturnedQtysForPo(ref.read(purchasingRepositoryProvider));
});
