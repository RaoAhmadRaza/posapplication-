import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/receivables_aging.dart';
import '../failures/customer_failure.dart';
import '../repositories/customers_repository.dart';
import '../../data/repositories/customers_repository_impl.dart';

class LoadReceivablesAging {
  final CustomersRepository _repo;
  LoadReceivablesAging(this._repo);

  Future<(ReceivablesAging?, CustomerFailure?)> call() {
    return _repo.loadReceivablesAging();
  }
}

final loadReceivablesAgingUseCaseProvider =
    Provider<LoadReceivablesAging>((ref) {
  return LoadReceivablesAging(ref.read(customersRepositoryProvider));
});
