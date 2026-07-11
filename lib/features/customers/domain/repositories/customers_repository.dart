import '../entities/customer.dart';
import '../entities/customer_ledger.dart';
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
}
