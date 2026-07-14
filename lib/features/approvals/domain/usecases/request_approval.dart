import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/approval_failure.dart';
import '../repositories/approvals_repository.dart';
import '../../data/repositories/approvals_repository_impl.dart';

class RequestApproval {
  final ApprovalsRepository _repo;
  RequestApproval(this._repo);

  Future<(Map<String, dynamic>?, ApprovalFailure?)> call({
    required String type,
    required String entityType,
    required String entityId,
    double? amount,
    String? reason,
    String? correlationId,
  }) =>
      _repo.requestApproval(
        type: type,
        entityType: entityType,
        entityId: entityId,
        amount: amount,
        reason: reason,
        correlationId: correlationId,
      );
}

final requestApprovalUseCaseProvider = Provider<RequestApproval>((ref) {
  return RequestApproval(ref.read(approvalsRepositoryProvider));
});
