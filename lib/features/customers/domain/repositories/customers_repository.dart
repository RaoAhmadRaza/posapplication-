import '../entities/customer.dart';
import '../entities/customer_invoice.dart';
import '../entities/customer_ledger.dart';
import '../entities/customer_payment_result.dart';
import '../entities/receivables_aging.dart';
import '../failures/customer_failure.dart';

abstract class CustomersRepository {
  Future<(List<Customer>, CustomerFailure?)> loadCustomers({
    String? query,
    CustomerStatus? status,
  });
  Future<(Customer?, CustomerFailure?)> loadCustomer(String id);
  Future<(Customer?, CustomerFailure?)> createCustomer(
      Map<String, dynamic> data);
  Future<(Customer?, CustomerFailure?)> updateCustomer(
      String id, Map<String, dynamic> data);
  Future<(bool, CustomerFailure?)> softDeleteCustomer(String id);
  Future<(CustomerLedger?, CustomerFailure?)> loadCustomerLedger(
      String customerId);
  Future<(ReceivablesAging?, CustomerFailure?)> loadReceivablesAging();
  Future<(List<CustomerInvoice>, CustomerFailure?)> loadUnpaidInvoices(
      String customerId);
  Future<(CustomerPaymentResult?, CustomerFailure?)> recordCustomerPayment({
    required String customerId,
    required String invoiceId,
    required String method,
    required double amount,
    String? reference,
    String? bankAccountId,
    String? notes,
  });
}
