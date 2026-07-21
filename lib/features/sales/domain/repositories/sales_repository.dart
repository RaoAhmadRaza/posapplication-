import '../entities/customer.dart';
import '../entities/cashier_session.dart';
import '../entities/invoice.dart';
import '../entities/sale_result.dart';
import '../entities/held_sale.dart';
import '../failures/sales_failure.dart';

abstract class SalesRepository {
  Future<(CashierSession?, SalesFailure?)> openSession({
    required String branchId,
    double openingFloat = 0,
  });
  Future<(Map<String, dynamic>?, SalesFailure?)> closeSession({
    required String sessionId,
    required double closingFloat,
    String? notes,
  });
  Future<(SaleResult?, SalesFailure?)> createSale({
    required String branchId,
    String? customerId,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    String? notes,
    String? sessionId,
  });
  Future<(List<Invoice>, SalesFailure?)> loadInvoices({
    String? branchId,
    String? status,
    String? customerId,
    String? search,
    int limit = 50,
    int offset = 0,
  });
  Future<(Map<String, dynamic>?, SalesFailure?)> loadInvoiceDetail(String id);
  Future<(List<Customer>, SalesFailure?)> loadCustomers({String? query});
  Future<(Customer?, SalesFailure?)> createCustomer(Map<String, dynamic> data);
  Future<(SaleResult?, SalesFailure?)> createSalesReturn({
    required String originalInvoiceId,
    required List<Map<String, dynamic>> items,
    required String reason,
    required List<Map<String, dynamic>> refunds,
  });
  Future<(bool, SalesFailure?)> holdSale({
    required String branchId,
    String? sessionId,
    String? customerId,
    required Map<String, dynamic> cartJson,
    required String label,
  });
  Future<(List<HeldSale>, SalesFailure?)> loadHeldSales({String? branchId});
  Future<(bool, SalesFailure?)> deleteHeldSale(String id);
  Future<(bool, SalesFailure?)> voidInvoice({
    required String invoiceId,
    required String reason,
  });
  Future<(CashierSession?, SalesFailure?)> loadOpenSession(String branchId);
  Future<(Map<String, dynamic>?, SalesFailure?)> loadSessionSales(
      String sessionId);
}
