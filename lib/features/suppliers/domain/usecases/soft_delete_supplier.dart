import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/supplier_failure.dart';
import '../repositories/suppliers_repository.dart';
import '../../data/repositories/suppliers_repository_impl.dart';

class SoftDeleteSupplier {
  final SuppliersRepository _repo;
  SoftDeleteSupplier(this._repo);

  Future<(bool, SupplierFailure?)> call(String id) {
    return _repo.softDeleteSupplier(id);
  }
}

final softDeleteSupplierUseCaseProvider = Provider<SoftDeleteSupplier>((ref) {
  return SoftDeleteSupplier(ref.read(suppliersRepositoryProvider));
});
