import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/customer_payment_result.dart';
import '../failures/customer_failure.dart';
import '../repositories/customers_repository.dart';
import '../../data/repositories/customers_repository_impl.dart';

class RecordCustomerPayment {
  final CustomersRepository _repo;
  RecordCustomerPayment(this._repo);

  Future<(CustomerPaymentResult?, CustomerFailure?)> call({
    required String customerId,
    required String invoiceId,
    required String method,
    required double amount,
    String? reference,
    String? bankAccountId,
    String? notes,
  }) {
    return _repo.recordCustomerPayment(
      customerId: customerId,
      invoiceId: invoiceId,
      method: method,
      amount: amount,
      reference: reference,
      bankAccountId: bankAccountId,
      notes: notes,
    );
  }
}

final recordCustomerPaymentUseCaseProvider =
    Provider<RecordCustomerPayment>((ref) {
  return RecordCustomerPayment(ref.read(customersRepositoryProvider));
});
