import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/approval.dart';
import '../failures/approval_failure.dart';
import '../repositories/approvals_repository.dart';
import '../../data/repositories/approvals_repository_impl.dart';

class LoadApprovalDetail {
  final ApprovalsRepository _repo;
  LoadApprovalDetail(this._repo);

  Future<(ApprovalRequest?, List<ApprovalAction>, ApprovalWorkflow?,
      ApprovalFailure?)> call(String id) => _repo.loadDetail(id);
}

final loadApprovalDetailUseCaseProvider = Provider<LoadApprovalDetail>((ref) {
  return LoadApprovalDetail(ref.read(approvalsRepositoryProvider));
});
