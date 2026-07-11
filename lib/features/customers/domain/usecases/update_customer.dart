import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/customer.dart';
import '../failures/customer_failure.dart';
import '../repositories/customers_repository.dart';
import '../../data/repositories/customers_repository_impl.dart';

class UpdateCustomer {
  final CustomersRepository _repo;
  UpdateCustomer(this._repo);

  Future<(Customer?, CustomerFailure?)> call(
      String id, Map<String, dynamic> data) {
    return _repo.updateCustomer(id, data);
  }
}

final updateCustomerUseCaseProvider = Provider<UpdateCustomer>((ref) {
  return UpdateCustomer(ref.read(customersRepositoryProvider));
});
