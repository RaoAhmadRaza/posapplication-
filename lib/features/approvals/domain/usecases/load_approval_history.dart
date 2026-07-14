import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/approval.dart';
import '../failures/approval_failure.dart';
import '../repositories/approvals_repository.dart';
import '../../data/repositories/approvals_repository_impl.dart';

class LoadApprovalHistory {
  final ApprovalsRepository _repo;
  LoadApprovalHistory(this._repo);

  Future<(List<ApprovalRequest>, ApprovalFailure?)> call() =>
      _repo.loadHistory();
}

final loadApprovalHistoryUseCaseProvider =
    Provider<LoadApprovalHistory>((ref) {
  return LoadApprovalHistory(ref.read(approvalsRepositoryProvider));
});
