import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/failures/sales_failure.dart';
import '../../data/repositories/sales_repository_impl.dart';
import '../../domain/repositories/sales_repository.dart';

class CloseSession {
  final SalesRepository _repo;
  CloseSession(this._repo);

  Future<(Map<String, dynamic>?, SalesFailure?)> call({
    required String sessionId,
    required double closingFloat,
    String? notes,
  }) async {
    return _repo.closeSession(
      sessionId: sessionId,
      closingFloat: closingFloat,
      notes: notes,
    );
  }
}

final closeSessionUseCaseProvider = Provider<CloseSession>((ref) {
  return CloseSession(ref.read(salesRepositoryProvider));
});
