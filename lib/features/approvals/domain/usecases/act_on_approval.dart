import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/approval_failure.dart';
import '../repositories/approvals_repository.dart';
import '../../data/repositories/approvals_repository_impl.dart';

class ActOnApproval {
  final ApprovalsRepository _repo;
  ActOnApproval(this._repo);

  Future<ApprovalFailure?> call({
    required String requestId,
    required String action,
    String? comments,
  }) =>
      _repo.act(requestId: requestId, action: action, comments: comments);
}

final actOnApprovalUseCaseProvider = Provider<ActOnApproval>((ref) {
  return ActOnApproval(ref.read(approvalsRepositoryProvider));
});
