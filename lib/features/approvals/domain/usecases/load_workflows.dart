import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/approval.dart';
import '../failures/approval_failure.dart';
import '../repositories/approvals_repository.dart';
import '../../data/repositories/approvals_repository_impl.dart';

class LoadWorkflows {
  final ApprovalsRepository _repo;
  LoadWorkflows(this._repo);

  Future<(List<ApprovalWorkflow>, ApprovalFailure?)> call({String? type}) =>
      _repo.loadWorkflows(type: type);
}

final loadWorkflowsUseCaseProvider = Provider<LoadWorkflows>((ref) {
  return LoadWorkflows(ref.read(approvalsRepositoryProvider));
});
