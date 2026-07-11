import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/purchase_results.dart';
import '../failures/purchase_failure.dart';
import '../repositories/purchasing_repository.dart';
import '../../data/repositories/purchasing_repository_impl.dart';

class CreatePurchaseInvoice {
  final PurchasingRepository _repo;
  CreatePurchaseInvoice(this._repo);

  Future<(InvoiceCreateResult?, PurchaseFailure?)> call({
    required String poId,
    String? grnId,
    String? supplierInvoiceNumber,
    required double amount,
    required double taxAmount,
    DateTime? dueDate,
    String? notes,
  }) {
    return _repo.createPurchaseInvoice(
      poId: poId,
      grnId: grnId,
      supplierInvoiceNumber: supplierInvoiceNumber,
      amount: amount,
      taxAmount: taxAmount,
      dueDate: dueDate,
      notes: notes,
    );
  }
}

final createPurchaseInvoiceUseCaseProvider =
    Provider<CreatePurchaseInvoice>((ref) {
  return CreatePurchaseInvoice(ref.read(purchasingRepositoryProvider));
});
