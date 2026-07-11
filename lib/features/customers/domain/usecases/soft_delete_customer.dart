import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/customer_failure.dart';
import '../repositories/customers_repository.dart';
import '../../data/repositories/customers_repository_impl.dart';

class SoftDeleteCustomer {
  final CustomersRepository _repo;
  SoftDeleteCustomer(this._repo);

  Future<(bool, CustomerFailure?)> call(String id) {
    return _repo.softDeleteCustomer(id);
  }
}

final softDeleteCustomerUseCaseProvider = Provider<SoftDeleteCustomer>((ref) {
  return SoftDeleteCustomer(ref.read(customersRepositoryProvider));
});
