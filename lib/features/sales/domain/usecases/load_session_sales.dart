import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/sales_failure.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/sales_repository.dart';

class LoadSessionSales {
  final SalesRepository _repo;
  LoadSessionSales(this._repo);

  Future<(Map<String, dynamic>?, SalesFailure?)> call(String sessionId) async {
    return _repo.loadSessionSales(sessionId);
  }
}

final loadSessionSalesUseCaseProvider = Provider<LoadSessionSales>((ref) {
  return LoadSessionSales(ref.read(salesRepositoryProvider));
});
