import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/customer.dart';
import '../../domain/failures/sales_failure.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/sales_repository.dart';

class CreateCustomer {
  final SalesRepository _repo;
  CreateCustomer(this._repo);

  Future<(Customer?, SalesFailure?)> call(Map<String, dynamic> data) async {
    return _repo.createCustomer(data);
  }
}

final createCustomerUseCaseProvider = Provider<CreateCustomer>((ref) {
  return CreateCustomer(ref.read(salesRepositoryProvider));
});
