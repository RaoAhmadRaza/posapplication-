import '../entities/supplier.dart';
import '../entities/supplier_ledger.dart';
import '../entities/payables_aging.dart';
import '../failures/supplier_failure.dart';

abstract class SuppliersRepository {
  Future<(List<Supplier>, SupplierFailure?)> loadSuppliers({
    String? query,
    SupplierStatus? status,
  });
  Future<(Supplier?, SupplierFailure?)> loadSupplier(String id);
  Future<(Supplier?, SupplierFailure?)> createSupplier(
      Map<String, dynamic> data);
  Future<(Supplier?, SupplierFailure?)> updateSupplier(
      String id, Map<String, dynamic> data);
  Future<(bool, SupplierFailure?)> softDeleteSupplier(String id);
  Future<(SupplierLedger?, SupplierFailure?)> loadSupplierLedger(
      String supplierId);
  Future<(PayablesAging?, SupplierFailure?)> loadPayablesAging();
}
