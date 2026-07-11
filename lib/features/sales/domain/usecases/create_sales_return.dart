import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/sale_result.dart';
import '../../domain/failures/sales_failure.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/sales_repository.dart';

class CreateSalesReturn {
  final SalesRepository _repo;
  CreateSalesReturn(this._repo);

  Future<(SaleResult?, SalesFailure?)> call({
    required String originalInvoiceId,
    required List<Map<String, dynamic>> items,
    required String reason,
    required List<Map<String, dynamic>> refunds,
  }) async {
    return _repo.createSalesReturn(
      originalInvoiceId: originalInvoiceId,
      items: items,
      reason: reason,
      refunds: refunds,
    );
  }
}

final createSalesReturnUseCaseProvider = Provider<CreateSalesReturn>((ref) {
  return CreateSalesReturn(ref.read(salesRepositoryProvider));
});
