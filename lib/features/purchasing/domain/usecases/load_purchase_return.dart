import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/purchase_return.dart';
import '../entities/purchase_return_item.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class LoadPurchaseReturn {
  final PurchasingRepository _repo;
  LoadPurchaseReturn(this._repo);

  Future<(PurchaseReturn?, List<PurchaseReturnItem>, PurchaseFailure?)> call(
      String id) {
    return _repo.loadPurchaseReturn(id);
  }
}

final loadPurchaseReturnUseCaseProvider =
    Provider<LoadPurchaseReturn>((ref) {
  return LoadPurchaseReturn(ref.read(purchasingRepositoryProvider));
});
