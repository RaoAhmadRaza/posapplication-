import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/sales_failure.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/sales_repository.dart';

class VoidInvoice {
  final SalesRepository _repo;
  VoidInvoice(this._repo);

  Future<(bool, SalesFailure?)> call({
    required String invoiceId,
    required String reason,
  }) async {
    return _repo.voidInvoice(invoiceId: invoiceId, reason: reason);
  }
}

final voidInvoiceUseCaseProvider = Provider<VoidInvoice>((ref) {
  return VoidInvoice(ref.read(salesRepositoryProvider));
});
