import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/sale_result.dart';
import '../../domain/failures/sales_failure.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/sales_repository.dart';

class CreateSale {
  final SalesRepository _repo;
  CreateSale(this._repo);

  Future<(SaleResult?, SalesFailure?)> call({
    required String branchId,
    String? customerId,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    String? notes,
    String? sessionId,
  }) async {
    return _repo.createSale(
      branchId: branchId,
      customerId: customerId,
      items: items,
      payments: payments,
      notes: notes,
      sessionId: sessionId,
    );
  }
}

final createSaleUseCaseProvider = Provider<CreateSale>((ref) {
  return CreateSale(ref.read(salesRepositoryProvider));
});
