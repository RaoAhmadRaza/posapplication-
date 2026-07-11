import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/supplier.dart';
import '../failures/supplier_failure.dart';
import '../repositories/suppliers_repository.dart';
import '../../data/repositories/suppliers_repository_impl.dart';

class CreateSupplier {
  final SuppliersRepository _repo;
  CreateSupplier(this._repo);

  Future<(Supplier?, SupplierFailure?)> call(Map<String, dynamic> data) {
    return _repo.createSupplier(data);
  }
}

final createSupplierUseCaseProvider = Provider<CreateSupplier>((ref) {
  return CreateSupplier(ref.read(suppliersRepositoryProvider));
});
