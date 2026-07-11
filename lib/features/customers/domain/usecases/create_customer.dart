import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/customer.dart';
import '../failures/customer_failure.dart';
import '../repositories/customers_repository.dart';
import '../../data/repositories/customers_repository_impl.dart';

class CreateCustomer {
  final CustomersRepository _repo;
  CreateCustomer(this._repo);

  Future<(Customer?, CustomerFailure?)> call(Map<String, dynamic> data) {
    return _repo.createCustomer(data);
  }
}

final createCustomerUseCaseProvider = Provider<CreateCustomer>((ref) {
  return CreateCustomer(ref.read(customersRepositoryProvider));
});
