import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/purchase_failure.dart';
import '../../domain/usecases/record_supplier_payment.dart';
import 'purchase_invoices_controller.dart';

final purchasePaymentsProvider =
    NotifierProvider<PurchasePaymentsController, void>(
  PurchasePaymentsController.new,
);

class PurchasePaymentsController extends Notifier<void> {
  @override
  void build() {}

  Future<PurchaseFailure?> recordPayment({
    required String supplierId,
    String? invoiceId,
    required String method,
    required double amount,
    String? reference,
    String? notes,
  }) async {
    final (_, failure) =
        await ref.read(recordSupplierPaymentUseCaseProvider).call(
              supplierId: supplierId,
              invoiceId: invoiceId,
              method: method,
              amount: amount,
              reference: reference,
              notes: notes,
            );
    if (failure != null) return failure;
    ref.invalidate(purchaseInvoicesProvider);
    if (invoiceId != null) {
      ref.invalidate(invoicePaymentsProvider(invoiceId));
    }
    return null;
  }
}
