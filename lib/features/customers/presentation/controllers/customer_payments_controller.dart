import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/customer_invoice.dart';
import '../../domain/entities/customer_payment_result.dart';
import '../../domain/failures/customer_failure.dart';
import '../../domain/usecases/load_unpaid_invoices.dart';
import '../../domain/usecases/record_customer_payment.dart';
import 'customers_controller.dart';

/// Unpaid / partially paid invoices for a customer — the collection pick list.
final unpaidInvoicesProvider = FutureProvider.autoDispose
    .family<List<CustomerInvoice>, String>((ref, customerId) async {
  final (invoices, failure) =
      await ref.read(loadUnpaidInvoicesUseCaseProvider).call(customerId);
  if (failure != null) throw failure;
  return invoices;
});

final customerPaymentsProvider =
    NotifierProvider<CustomerPaymentsController, void>(
  CustomerPaymentsController.new,
);

class CustomerPaymentsController extends Notifier<void> {
  @override
  void build() {}

  Future<(CustomerPaymentResult?, CustomerFailure?)> recordPayment({
    required String customerId,
    required String invoiceId,
    required String method,
    required double amount,
    String? reference,
    String? bankAccountId,
    String? notes,
  }) async {
    final (result, failure) =
        await ref.read(recordCustomerPaymentUseCaseProvider).call(
              customerId: customerId,
              invoiceId: invoiceId,
              method: method,
              amount: amount,
              reference: reference,
              bankAccountId: bankAccountId,
              notes: notes,
            );
    if (failure != null) return (null, failure);
    ref.invalidate(unpaidInvoicesProvider(customerId));
    ref.invalidate(customerLedgerProvider(customerId));
    ref.invalidate(customerOutstandingProvider(customerId));
    ref.invalidate(receivablesAgingProvider);
    return (result, null);
  }
}
