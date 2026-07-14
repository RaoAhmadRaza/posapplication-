import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/approval.dart';
import '../../domain/failures/approval_failure.dart';
import '../../domain/usecases/act_on_approval.dart';
import '../../domain/usecases/cancel_approval.dart';
import '../../domain/usecases/load_approval_detail.dart';
import '../../domain/usecases/load_approval_history.dart';
import '../../domain/usecases/load_open_approvals.dart';

typedef ApprovalDetail = ({
  ApprovalRequest request,
  List<ApprovalAction> actions,
  ApprovalWorkflow workflow,
});

/// Open (PENDING + ESCALATED) requests. Filtering by type/status is done in
/// the page from this single list.
class PendingApprovalsController
    extends AsyncNotifier<List<ApprovalRequest>> {
  @override
  Future<List<ApprovalRequest>> build() async {
    final (rows, failure) =
        await ref.read(loadOpenApprovalsUseCaseProvider).call();
    if (failure != null) throw failure;
    return rows;
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final (rows, failure) =
          await ref.read(loadOpenApprovalsUseCaseProvider).call();
      if (failure != null) throw failure;
      return rows;
    });
  }
}

final pendingApprovalsControllerProvider =
    AsyncNotifierProvider<PendingApprovalsController, List<ApprovalRequest>>(
  PendingApprovalsController.new,
);

/// Badge count for the hub/nav entry (0 while loading or on error).
final pendingApprovalsCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(pendingApprovalsControllerProvider).maybeWhen(
        data: (rows) => rows.length,
        orElse: () => 0,
      );
});

final approvalHistoryProvider =
    FutureProvider.autoDispose<List<ApprovalRequest>>((ref) async {
  final (rows, failure) =
      await ref.read(loadApprovalHistoryUseCaseProvider).call();
  if (failure != null) throw failure;
  return rows;
});

final approvalDetailProvider =
    FutureProvider.autoDispose.family<ApprovalDetail, String>((ref, id) async {
  final (request, actions, workflow, failure) =
      await ref.read(loadApprovalDetailUseCaseProvider).call(id);
  if (failure != null) throw failure;
  if (request == null || workflow == null) {
    throw ApprovalRequestNotFoundFailure();
  }
  return (request: request, actions: actions, workflow: workflow);
});

class ApprovalActions {
  ApprovalActions(this._ref);
  final Ref _ref;

  void _invalidate(String requestId) {
    _ref.invalidate(approvalDetailProvider(requestId));
    _ref.invalidate(pendingApprovalsControllerProvider);
    _ref.invalidate(approvalHistoryProvider);
  }

  Future<ApprovalFailure?> act({
    required String requestId,
    required String action,
    String? comments,
  }) async {
    final failure = await _ref.read(actOnApprovalUseCaseProvider).call(
          requestId: requestId,
          action: action,
          comments: comments,
        );
    if (failure != null) return failure;
    _invalidate(requestId);
    return null;
  }

  Future<ApprovalFailure?> cancel({
    required String requestId,
    String? reason,
  }) async {
    final failure = await _ref
        .read(cancelApprovalUseCaseProvider)
        .call(requestId: requestId, reason: reason);
    if (failure != null) return failure;
    _invalidate(requestId);
    return null;
  }
}

final approvalActionsProvider =
    Provider<ApprovalActions>((ref) => ApprovalActions(ref));
