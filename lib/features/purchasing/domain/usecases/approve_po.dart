import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/purchase_results.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class ApprovePo {
  final PurchasingRepository _repo;
  ApprovePo(this._repo);

  Future<(PoStatusResult?, PurchaseFailure?)> call(String id) {
    return _repo.approvePurchaseOrder(id);
  }
}

final approvePoUseCaseProvider = Provider<ApprovePo>((ref) {
  return ApprovePo(ref.read(purchasingRepositoryProvider));
});
