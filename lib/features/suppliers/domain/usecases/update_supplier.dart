import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/supplier.dart';
import '../failures/supplier_failure.dart';
import '../repositories/suppliers_repository.dart';
import '../../data/repositories/suppliers_repository_impl.dart';

class UpdateSupplier {
  final SuppliersRepository _repo;
  UpdateSupplier(this._repo);

  Future<(Supplier?, SupplierFailure?)> call(
      String id, Map<String, dynamic> data) {
    return _repo.updateSupplier(id, data);
  }
}

final updateSupplierUseCaseProvider = Provider<UpdateSupplier>((ref) {
  return UpdateSupplier(ref.read(suppliersRepositoryProvider));
});
