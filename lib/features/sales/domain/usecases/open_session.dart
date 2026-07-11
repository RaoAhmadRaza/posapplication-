import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/cashier_session.dart';
import '../../domain/failures/sales_failure.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/sales_repository.dart';

class OpenSession {
  final SalesRepository _repo;
  OpenSession(this._repo);

  Future<(CashierSession?, SalesFailure?)> call({
    required String branchId,
    double openingFloat = 0,
  }) async {
    return _repo.openSession(branchId: branchId, openingFloat: openingFloat);
  }
}

final openSessionUseCaseProvider = Provider<OpenSession>((ref) {
  return OpenSession(ref.read(salesRepositoryProvider));
});
