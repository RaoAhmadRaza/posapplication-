import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/approval_failure.dart';
import '../repositories/approvals_repository.dart';
import '../../data/repositories/approvals_repository_impl.dart';

class CancelApproval {
  final ApprovalsRepository _repo;
  CancelApproval(this._repo);

  Future<ApprovalFailure?> call({
    required String requestId,
    String? reason,
  }) =>
      _repo.cancel(requestId: requestId, reason: reason);
}

final cancelApprovalUseCaseProvider = Provider<CancelApproval>((ref) {
  return CancelApproval(ref.read(approvalsRepositoryProvider));
});
