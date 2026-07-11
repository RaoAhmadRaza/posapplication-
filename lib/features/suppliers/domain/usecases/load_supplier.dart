import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/supplier.dart';
import '../failures/supplier_failure.dart';
import '../repositories/suppliers_repository.dart';
import '../../data/repositories/suppliers_repository_impl.dart';

class LoadSupplier {
  final SuppliersRepository _repo;
  LoadSupplier(this._repo);

  Future<(Supplier?, SupplierFailure?)> call(String id) {
    return _repo.loadSupplier(id);
  }
}

final loadSupplierUseCaseProvider = Provider<LoadSupplier>((ref) {
  return LoadSupplier(ref.read(suppliersRepositoryProvider));
});
