import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/payables_aging.dart';
import '../failures/supplier_failure.dart';
import '../repositories/suppliers_repository.dart';
import '../../data/repositories/suppliers_repository_impl.dart';

class LoadPayablesAging {
  final SuppliersRepository _repo;
  LoadPayablesAging(this._repo);

  Future<(PayablesAging?, SupplierFailure?)> call() {
    return _repo.loadPayablesAging();
  }
}

final loadPayablesAgingUseCaseProvider = Provider<LoadPayablesAging>((ref) {
  return LoadPayablesAging(ref.read(suppliersRepositoryProvider));
});
