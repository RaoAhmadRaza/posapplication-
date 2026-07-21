import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/failures/sales_failure.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/sales_repository.dart';

class LoadInvoices {
  final SalesRepository _repo;
  LoadInvoices(this._repo);

  Future<(List<Invoice>, SalesFailure?)> call({
    String? branchId,
    String? status,
    String? customerId,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    return _repo.loadInvoices(
      branchId: branchId,
      status: status,
      customerId: customerId,
      search: search,
      limit: limit,
      offset: offset,
    );
  }
}

final loadInvoicesUseCaseProvider = Provider<LoadInvoices>((ref) {
  return LoadInvoices(ref.read(salesRepositoryProvider));
});
