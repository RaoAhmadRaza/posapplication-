import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/cashier_session.dart';
import '../../domain/failures/sales_failure.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/sales_repository.dart';

class LoadOpenSession {
  final SalesRepository _repo;
  LoadOpenSession(this._repo);

  Future<(CashierSession?, SalesFailure?)> call(String branchId) async {
    return _repo.loadOpenSession(branchId);
  }
}

final loadOpenSessionUseCaseProvider = Provider<LoadOpenSession>((ref) {
  return LoadOpenSession(ref.read(salesRepositoryProvider));
});
