import '../entities/approval.dart';
import '../failures/approval_failure.dart';

abstract class ApprovalsRepository {
  /// Open requests (PENDING + ESCALATED) for the tenant.
  Future<(List<ApprovalRequest>, ApprovalFailure?)> loadOpenRequests();

  /// Completed requests (APPROVED/REJECTED/EXPIRED/CANCELLED).
  Future<(List<ApprovalRequest>, ApprovalFailure?)> loadHistory();

  /// One request + its action timeline + the workflow (for the level ladder).
  Future<(ApprovalRequest?, List<ApprovalAction>, ApprovalWorkflow?,
      ApprovalFailure?)> loadDetail(String id);

  Future<ApprovalFailure?> act({
    required String requestId,
    required String action,
    String? comments,
  });

  Future<ApprovalFailure?> cancel({
    required String requestId,
    String? reason,
  });

  /// Configured workflows (optionally one type), newest config surface.
  Future<(List<ApprovalWorkflow>, ApprovalFailure?)> loadWorkflows({
    String? type,
  });

  /// Tenant role names for the levels editor.
  Future<(List<String>, ApprovalFailure?)> loadRoleNames();

  /// Insert or update a workflow config. Returns the workflow id on success.
  Future<(String?, ApprovalFailure?)> upsertWorkflow({
    String? id,
    required ApprovalWorkflowType type,
    required String name,
    String? description,
    double? thresholdAmount,
    required List<ApprovalLevel> levels,
    int escalationTtlHours = 24,
    bool isActive = true,
  });

  /// Manual raise. Returns the RPC result map ({required, request_id?, ...}).
  Future<(Map<String, dynamic>?, ApprovalFailure?)> requestApproval({
    required String type,
    required String entityType,
    required String entityId,
    double? amount,
    String? reason,
    String? correlationId,
  });
}
