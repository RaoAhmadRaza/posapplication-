import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/purchase_invoice.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class LoadPurchaseInvoices {
  final PurchasingRepository _repo;
  LoadPurchaseInvoices(this._repo);

  Future<(List<PurchaseInvoice>, PurchaseFailure?)> call({
    PurchaseInvoiceStatus? status,
    String? poId,
  }) {
    return _repo.loadPurchaseInvoices(status: status, poId: poId);
  }
}

final loadPurchaseInvoicesUseCaseProvider =
    Provider<LoadPurchaseInvoices>((ref) {
  return LoadPurchaseInvoices(ref.read(purchasingRepositoryProvider));
});
