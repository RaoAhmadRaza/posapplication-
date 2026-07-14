import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/approval.dart';
import '../../domain/failures/approval_failure.dart';
import '../../domain/usecases/load_role_names.dart';
import '../../domain/usecases/load_workflows.dart';
import '../../domain/usecases/upsert_workflow.dart';

class WorkflowsController extends AsyncNotifier<List<ApprovalWorkflow>> {
  @override
  Future<List<ApprovalWorkflow>> build() async {
    final (rows, failure) = await ref.read(loadWorkflowsUseCaseProvider).call();
    if (failure != null) throw failure;
    return rows;
  }

  Future<void> _reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final (rows, failure) =
          await ref.read(loadWorkflowsUseCaseProvider).call();
      if (failure != null) throw failure;
      return rows;
    });
  }

  Future<void> refresh() => _reload();

  Future<ApprovalFailure?> upsert({
    String? id,
    required ApprovalWorkflowType type,
    required String name,
    String? description,
    double? thresholdAmount,
    required List<ApprovalLevel> levels,
    int escalationTtlHours = 24,
    bool isActive = true,
  }) async {
    final (_, failure) = await ref.read(upsertWorkflowUseCaseProvider).call(
          id: id,
          type: type,
          name: name,
          description: description,
          thresholdAmount: thresholdAmount,
          levels: levels,
          escalationTtlHours: escalationTtlHours,
          isActive: isActive,
        );
    if (failure != null) return failure;
    await _reload();
    return null;
  }

  /// Soft-delete = deactivate through upsert (is_active=false), preserving
  /// the rest of the config.
  Future<ApprovalFailure?> setActive(
      ApprovalWorkflow workflow, bool isActive) {
    return upsert(
      id: workflow.id,
      type: workflow.workflowType,
      name: workflow.name,
      description: workflow.description,
      thresholdAmount: workflow.thresholdAmount,
      levels: workflow.levels,
      escalationTtlHours: workflow.escalationTtlHours,
      isActive: isActive,
    );
  }
}

final workflowsControllerProvider =
    AsyncNotifierProvider<WorkflowsController, List<ApprovalWorkflow>>(
  WorkflowsController.new,
);

/// Tenant role names for the levels editor role dropdown.
final tenantRoleNamesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  final (names, failure) =
      await ref.read(loadRoleNamesUseCaseProvider).call();
  if (failure != null) throw failure;
  return names;
});
