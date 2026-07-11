import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/sales_failure.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/sales_repository.dart';

class HoldSale {
  final SalesRepository _repo;
  HoldSale(this._repo);

  Future<(bool, SalesFailure?)> call({
    required String branchId,
    String? sessionId,
    String? customerId,
    required Map<String, dynamic> cartJson,
    required String label,
  }) async {
    return _repo.holdSale(
      branchId: branchId,
      sessionId: sessionId,
      customerId: customerId,
      cartJson: cartJson,
      label: label,
    );
  }
}

final holdSaleUseCaseProvider = Provider<HoldSale>((ref) {
  return HoldSale(ref.read(salesRepositoryProvider));
});
