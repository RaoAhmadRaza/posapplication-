import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/sales_failure.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/sales_repository.dart';

class LoadInvoiceDetail {
  final SalesRepository _repo;
  LoadInvoiceDetail(this._repo);

  Future<(Map<String, dynamic>?, SalesFailure?)> call(String id) async {
    return _repo.loadInvoiceDetail(id);
  }
}

final loadInvoiceDetailUseCaseProvider = Provider<LoadInvoiceDetail>((ref) {
  return LoadInvoiceDetail(ref.read(salesRepositoryProvider));
});
