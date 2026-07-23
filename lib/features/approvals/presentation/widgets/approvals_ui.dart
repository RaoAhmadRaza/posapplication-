import 'package:flutter/widgets.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/approval.dart';

/// Shared presentation helpers for the approvals module: label maps, pill-tone
/// mappers, urgency derivation and a short date format. Pure mapping — no
/// business logic, no data access.

const approvalStatusLabels = {
  ApprovalStatus.pending: 'Pending',
  ApprovalStatus.approved: 'Approved',
  ApprovalStatus.rejected: 'Rejected',
  ApprovalStatus.escalated: 'Escalated',
  ApprovalStatus.expired: 'Expired',
  ApprovalStatus.cancelled: 'Cancelled',
};

const approvalTypeLabels = {
  ApprovalWorkflowType.purchaseOrder: 'Purchase Order',
  ApprovalWorkflowType.stockAdjustment: 'Stock Adjustment',
  ApprovalWorkflowType.discountOverride: 'Discount Override',
  ApprovalWorkflowType.payrollDisbursement: 'Payroll Disbursement',
  ApprovalWorkflowType.creditLimitChange: 'Credit Limit Change',
  ApprovalWorkflowType.priceChange: 'Price Change',
  ApprovalWorkflowType.refund: 'Refund',
  ApprovalWorkflowType.expense: 'Expense',
};

/// Type label for a request, falling back to the raw entity type when the
/// workflow type was not embedded on load.
String approvalRequestType(ApprovalRequest r) =>
    r.workflowType == null ? r.entityType : approvalTypeLabels[r.workflowType]!;

/// Human label for the entity a workflow routes (matches [approvalEntityRoute]).
const approvalEntityNouns = {
  'purchase_orders': 'purchase order',
  'payroll_runs': 'payroll run',
  'repair_jobs': 'repair job',
};

/// Best-effort deep link to the underlying entity from its `entity_type`.
/// Returns null when the module has no detail route we can target.
String? approvalEntityRoute(String entityType, String entityId) {
  return switch (entityType) {
    'purchase_orders' => '/purchasing/$entityId',
    'payroll_runs' => '/hr/payroll/$entityId',
    'repair_jobs' => '/repair/$entityId',
    _ => null,
  };
}

/// Status → pill tone, faithful to the pre-reskin colour choices.
AppPillTone approvalStatusTone(ApprovalStatus s) => switch (s) {
      ApprovalStatus.pending => AppPillTone.warning,
      ApprovalStatus.escalated => AppPillTone.danger,
      ApprovalStatus.approved => AppPillTone.success,
      ApprovalStatus.rejected => AppPillTone.danger,
      ApprovalStatus.expired => AppPillTone.neutral,
      ApprovalStatus.cancelled => AppPillTone.neutral,
    };

/// Dot colour for an activity action string (APPROVED/REJECTED/…).
Color approvalActionColor(LumColors lum, String action) =>
    switch (action.toUpperCase()) {
      'APPROVED' => lum.success,
      'REJECTED' => lum.danger,
      'CANCELLED' => lum.g400,
      'ESCALATED' => lum.warning,
      _ => lum.g400,
    };

/// Urgency shown top-right on an open request: escalated / overdue / due-soon,
/// else the relative age. Overdue and due-soon are derived from [expiresAt] —
/// no fabricated deadline. Closed requests have no urgency.
({String label, AppPillTone tone}) approvalUrgency(ApprovalRequest r) {
  if (r.status == ApprovalStatus.escalated) {
    return (label: 'Escalated', tone: AppPillTone.warning);
  }
  final expires = r.expiresAt;
  if (expires != null && r.isOpen) {
    final left = expires.difference(DateTime.now());
    if (left.isNegative) return (label: 'Overdue', tone: AppPillTone.danger);
    if (left.inHours < 6) return (label: 'Due soon', tone: AppPillTone.lumen);
  }
  return (label: approvalAge(r.createdAt), tone: AppPillTone.neutral);
}

/// Relative age like the design's "3d ago" / "6h ago".
String approvalAge(DateTime from) {
  final age = DateTime.now().difference(from);
  if (age.inDays >= 1) return '${age.inDays}d ago';
  if (age.inHours >= 1) return '${age.inHours}h ago';
  if (age.inMinutes >= 1) return '${age.inMinutes}m ago';
  return 'Just now';
}

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Short date like the design's "2 Jun" / "4 Jun, 08:00".
String approvalDateShort(DateTime? d, {bool withTime = false}) {
  if (d == null) return '—';
  final base = '${d.day} ${_months[d.month - 1]}';
  if (!withTime) return base;
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$base, $hh:$mm';
}
