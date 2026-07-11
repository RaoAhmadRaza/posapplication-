import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/purchase_results.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class RecordSupplierPayment {
  final PurchasingRepository _repo;
  RecordSupplierPayment(this._repo);

  Future<(PaymentResult?, PurchaseFailure?)> call({
    required String supplierId,
    String? invoiceId,
    required String method,
    required double amount,
    String? reference,
    String? notes,
  }) {
    return _repo.recordSupplierPayment(
      supplierId: supplierId,
      invoiceId: invoiceId,
      method: method,
      amount: amount,
      reference: reference,
      notes: notes,
    );
  }
}

final recordSupplierPaymentUseCaseProvider =
    Provider<RecordSupplierPayment>((ref) {
  return RecordSupplierPayment(ref.read(purchasingRepositoryProvider));
});
