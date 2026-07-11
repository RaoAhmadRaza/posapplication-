import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/customer.dart';
import '../failures/customer_failure.dart';
import '../repositories/customers_repository.dart';
import '../../data/repositories/customers_repository_impl.dart';

class LoadCustomers {
  final CustomersRepository _repo;
  LoadCustomers(this._repo);

  Future<(List<Customer>, CustomerFailure?)> call({
    String? query,
    CustomerStatus? status,
  }) {
    return _repo.loadCustomers(query: query, status: status);
  }
}

final loadCustomersUseCaseProvider = Provider<LoadCustomers>((ref) {
  return LoadCustomers(ref.read(customersRepositoryProvider));
});
