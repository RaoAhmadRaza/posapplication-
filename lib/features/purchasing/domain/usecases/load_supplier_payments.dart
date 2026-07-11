import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/supplier_payment.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class LoadSupplierPayments {
  final PurchasingRepository _repo;
  LoadSupplierPayments(this._repo);

  Future<(List<SupplierPayment>, PurchaseFailure?)> call({
    String? supplierId,
    String? invoiceId,
  }) {
    return _repo.loadSupplierPayments(
        supplierId: supplierId, invoiceId: invoiceId);
  }
}

final loadSupplierPaymentsUseCaseProvider =
    Provider<LoadSupplierPayments>((ref) {
  return LoadSupplierPayments(ref.read(purchasingRepositoryProvider));
});
