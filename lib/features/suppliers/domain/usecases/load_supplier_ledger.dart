import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/supplier_ledger.dart';
import '../failures/supplier_failure.dart';
import '../repositories/suppliers_repository.dart';
import '../../data/repositories/suppliers_repository_impl.dart';

class LoadSupplierLedger {
  final SuppliersRepository _repo;
  LoadSupplierLedger(this._repo);

  Future<(SupplierLedger?, SupplierFailure?)> call(String supplierId) {
    return _repo.loadSupplierLedger(supplierId);
  }
}

final loadSupplierLedgerUseCaseProvider = Provider<LoadSupplierLedger>((ref) {
  return LoadSupplierLedger(ref.read(suppliersRepositoryProvider));
});
