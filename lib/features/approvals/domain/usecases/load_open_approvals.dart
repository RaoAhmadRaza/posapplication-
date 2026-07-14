import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/approval.dart';
import '../failures/approval_failure.dart';
import '../repositories/approvals_repository.dart';
import '../../data/repositories/approvals_repository_impl.dart';

class LoadOpenApprovals {
  final ApprovalsRepository _repo;
  LoadOpenApprovals(this._repo);

  Future<(List<ApprovalRequest>, ApprovalFailure?)> call() =>
      _repo.loadOpenRequests();
}

final loadOpenApprovalsUseCaseProvider = Provider<LoadOpenApprovals>((ref) {
  return LoadOpenApprovals(ref.read(approvalsRepositoryProvider));
});
