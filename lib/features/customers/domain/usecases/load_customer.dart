import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/customer.dart';
import '../failures/customer_failure.dart';
import '../repositories/customers_repository.dart';
import '../../data/repositories/customers_repository_impl.dart';

class LoadCustomer {
  final CustomersRepository _repo;
  LoadCustomer(this._repo);

  Future<(Customer?, CustomerFailure?)> call(String id) {
    return _repo.loadCustomer(id);
  }
}

final loadCustomerUseCaseProvider = Provider<LoadCustomer>((ref) {
  return LoadCustomer(ref.read(customersRepositoryProvider));
});
