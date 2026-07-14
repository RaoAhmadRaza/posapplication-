import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/approval.dart';
import '../failures/approval_failure.dart';
import '../repositories/approvals_repository.dart';
import '../../data/repositories/approvals_repository_impl.dart';

class UpsertWorkflow {
  final ApprovalsRepository _repo;
  UpsertWorkflow(this._repo);

  Future<(String?, ApprovalFailure?)> call({
    String? id,
    required ApprovalWorkflowType type,
    required String name,
    String? description,
    double? thresholdAmount,
    required List<ApprovalLevel> levels,
    int escalationTtlHours = 24,
    bool isActive = true,
  }) =>
      _repo.upsertWorkflow(
        id: id,
        type: type,
        name: name,
        description: description,
        thresholdAmount: thresholdAmount,
        levels: levels,
        escalationTtlHours: escalationTtlHours,
        isActive: isActive,
      );
}

final upsertWorkflowUseCaseProvider = Provider<UpsertWorkflow>((ref) {
  return UpsertWorkflow(ref.read(approvalsRepositoryProvider));
});
