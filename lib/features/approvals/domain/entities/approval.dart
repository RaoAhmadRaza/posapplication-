// Approval domain entities + enums. Mirrors the approvals_* migrations
// (approval_status_enum(6), approval_workflow_type_enum(8), §3.17 tables).

enum ApprovalStatus { pending, approved, rejected, escalated, expired, cancelled }

enum ApprovalWorkflowType {
  purchaseOrder,
  stockAdjustment,
  discountOverride,
  payrollDisbursement,
  creditLimitChange,
  priceChange,
  refund,
  expense,
}

/// One rung of a workflow's approval ladder (from levels_json).
class ApprovalLevel {
  final int level;
  final String requiredRole;
  final int minApprovers;

  const ApprovalLevel({
    required this.level,
    required this.requiredRole,
    this.minApprovers = 1,
  });
}

class ApprovalWorkflow {
  final String id;
  final String tenantId;
  final ApprovalWorkflowType workflowType;
  final String name;
  final String? description;
  final double? thresholdAmount;
  final List<ApprovalLevel> levels;
  final int escalationTtlHours;
  final bool isActive;

  const ApprovalWorkflow({
    required this.id,
    required this.tenantId,
    required this.workflowType,
    required this.name,
    this.description,
    this.thresholdAmount,
    this.levels = const [],
    this.escalationTtlHours = 24,
    this.isActive = true,
  });

  int get levelCount => levels.length;

  ApprovalLevel? levelAt(int level) {
    for (final l in levels) {
      if (l.level == level) return l;
    }
    return null;
  }
}

class ApprovalRequest {
  final String id;
  final String tenantId;
  final String workflowId;
  final String entityType;
  final String entityId;
  final String requestorId;
  final ApprovalStatus status;
  final int currentLevel;
  final double? amount;
  final String? reason;
  final DateTime? expiresAt;
  final DateTime? escalatedAt;
  final DateTime? completedAt;
  final DateTime createdAt;

  /// Display-only, from embeds on load.
  final String? requestorName;
  final ApprovalWorkflowType? workflowType;
  final String? workflowName;

  const ApprovalRequest({
    required this.id,
    required this.tenantId,
    required this.workflowId,
    required this.entityType,
    required this.entityId,
    required this.requestorId,
    required this.status,
    required this.currentLevel,
    required this.createdAt,
    this.amount,
    this.reason,
    this.expiresAt,
    this.escalatedAt,
    this.completedAt,
    this.requestorName,
    this.workflowType,
    this.workflowName,
  });

  bool get isOpen =>
      status == ApprovalStatus.pending || status == ApprovalStatus.escalated;
}

class ApprovalAction {
  final String id;
  final String requestId;
  final String actorId;

  /// APPROVED / REJECTED / CANCELLED / ESCALATED (free-form varchar(20)).
  final String action;
  final int level;
  final String? comments;
  final DateTime actedAt;

  /// Display-only, from the actor embed on load.
  final String? actorName;

  const ApprovalAction({
    required this.id,
    required this.requestId,
    required this.actorId,
    required this.action,
    required this.level,
    required this.actedAt,
    this.comments,
    this.actorName,
  });
}
