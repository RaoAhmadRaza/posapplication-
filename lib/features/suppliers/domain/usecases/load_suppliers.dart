import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/supplier.dart';
import '../failures/supplier_failure.dart';
import '../repositories/suppliers_repository.dart';
import '../../data/repositories/suppliers_repository_impl.dart';

class LoadSuppliers {
  final SuppliersRepository _repo;
  LoadSuppliers(this._repo);

  Future<(List<Supplier>, SupplierFailure?)> call({
    String? query,
    SupplierStatus? status,
  }) {
    return _repo.loadSuppliers(query: query, status: status);
  }
}

final loadSuppliersUseCaseProvider = Provider<LoadSuppliers>((ref) {
  return LoadSuppliers(ref.read(suppliersRepositoryProvider));
});
