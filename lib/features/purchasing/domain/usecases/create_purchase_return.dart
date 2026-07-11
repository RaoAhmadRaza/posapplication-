import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/purchase_results.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class CreatePurchaseReturn {
  final PurchasingRepository _repo;
  CreatePurchaseReturn(this._repo);

  Future<(ReturnCreateResult?, PurchaseFailure?)> call({
    required String branchId,
    required String poId,
    String? grnId,
    String? invoiceId,
    required String reason,
    String? notes,
    required List<Map<String, dynamic>> items,
  }) {
    return _repo.createPurchaseReturn(
      branchId: branchId,
      poId: poId,
      grnId: grnId,
      invoiceId: invoiceId,
      reason: reason,
      notes: notes,
      items: items,
    );
  }
}

final createPurchaseReturnUseCaseProvider =
    Provider<CreatePurchaseReturn>((ref) {
  return CreatePurchaseReturn(ref.read(purchasingRepositoryProvider));
});
