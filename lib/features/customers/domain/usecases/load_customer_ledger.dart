import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/customer_ledger.dart';
import '../failures/customer_failure.dart';
import '../repositories/customers_repository.dart';
import '../../data/repositories/customers_repository_impl.dart';

class LoadCustomerLedger {
  final CustomersRepository _repo;
  LoadCustomerLedger(this._repo);

  Future<(CustomerLedger?, CustomerFailure?)> call(String customerId) {
    return _repo.loadCustomerLedger(customerId);
  }
}

final loadCustomerLedgerUseCaseProvider =
    Provider<LoadCustomerLedger>((ref) {
  return LoadCustomerLedger(ref.read(customersRepositoryProvider));
});
