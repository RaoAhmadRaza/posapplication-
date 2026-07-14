import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../domain/entities/approval.dart';

const approvalStatusLabels = {
  ApprovalStatus.pending: 'Pending',
  ApprovalStatus.approved: 'Approved',
  ApprovalStatus.rejected: 'Rejected',
  ApprovalStatus.escalated: 'Escalated',
  ApprovalStatus.expired: 'Expired',
  ApprovalStatus.cancelled: 'Cancelled',
};

Color approvalStatusColor(ApprovalStatus s) => switch (s) {
      ApprovalStatus.pending => AppColors.warning,
      ApprovalStatus.escalated => AppColors.destructive,
      ApprovalStatus.approved => AppColors.success,
      ApprovalStatus.rejected => AppColors.destructive,
      ApprovalStatus.expired => AppColors.textMuted,
      ApprovalStatus.cancelled => AppColors.textMuted,
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

/// A raw action string (APPROVED/REJECTED/CANCELLED/ESCALATED) → colour.
Color approvalActionColor(String action) => switch (action.toUpperCase()) {
      'APPROVED' => AppColors.success,
      'REJECTED' => AppColors.destructive,
      'CANCELLED' => AppColors.textMuted,
      'ESCALATED' => AppColors.warning,
      _ => AppColors.textMuted,
    };

class ApprovalStatusBadge extends StatelessWidget {
  const ApprovalStatusBadge({super.key, required this.status});
  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final color = approvalStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        approvalStatusLabels[status]!,
        style: AppTypography.caption
            .copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
