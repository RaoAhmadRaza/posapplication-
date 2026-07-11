import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/customer.dart';
import '../../domain/failures/sales_failure.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/sales_repository.dart';

class LoadCustomers {
  final SalesRepository _repo;
  LoadCustomers(this._repo);

  Future<(List<Customer>, SalesFailure?)> call({String? query}) async {
    return _repo.loadCustomers(query: query);
  }
}

final loadCustomersUseCaseProvider = Provider<LoadCustomers>((ref) {
  return LoadCustomers(ref.read(salesRepositoryProvider));
});
