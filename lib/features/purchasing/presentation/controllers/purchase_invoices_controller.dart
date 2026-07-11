import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/entities/supplier_payment.dart';
import '../../domain/entities/purchase_results.dart';
import '../../domain/failures/purchase_failure.dart';
import '../../domain/usecases/load_purchase_invoices.dart';
import '../../domain/usecases/create_purchase_invoice.dart';
import '../../domain/usecases/load_supplier_payments.dart';

final purchaseInvoicesProvider =
    AsyncNotifierProvider<PurchaseInvoicesController, List<PurchaseInvoice>>(
  PurchaseInvoicesController.new,
);

class PurchaseInvoicesController
    extends AsyncNotifier<List<PurchaseInvoice>> {
  PurchaseInvoiceStatus? _status;

  PurchaseInvoiceStatus? get statusFilter => _status;

  @override
  Future<List<PurchaseInvoice>> build() async {
    final (invoices, failure) = await ref
        .read(loadPurchaseInvoicesUseCaseProvider)
        .call(status: _status);
    if (failure != null) throw failure;
    return invoices;
  }

  Future<void> setStatus(PurchaseInvoiceStatus? status) async {
    _status = status;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final (invoices, failure) = await ref
          .read(loadPurchaseInvoicesUseCaseProvider)
          .call(status: _status);
      if (failure != null) throw failure;
      return invoices;
    });
  }

  void refresh() => ref.invalidateSelf();

  /// Returns the RPC result (incl. match_variance) on success, or a failure.
  Future<(InvoiceCreateResult?, PurchaseFailure?)> create({
    required String poId,
    String? grnId,
    String? supplierInvoiceNumber,
    required double amount,
    required double taxAmount,
    DateTime? dueDate,
    String? notes,
  }) async {
    final (result, failure) =
        await ref.read(createPurchaseInvoiceUseCaseProvider).call(
              poId: poId,
              grnId: grnId,
              supplierInvoiceNumber: supplierInvoiceNumber,
              amount: amount,
              taxAmount: taxAmount,
              dueDate: dueDate,
              notes: notes,
            );
    if (failure != null) return (null, failure);
    ref.invalidateSelf();
    return (result, null);
  }
}

/// Payments recorded against a single invoice.
final invoicePaymentsProvider = FutureProvider.autoDispose
    .family<List<SupplierPayment>, String>((ref, invoiceId) async {
  final (payments, failure) = await ref
      .read(loadSupplierPaymentsUseCaseProvider)
      .call(invoiceId: invoiceId);
  if (failure != null) throw failure;
  return payments;
});
