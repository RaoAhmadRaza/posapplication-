import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../domain/entities/repair_job.dart';

const repairStatusLabels = {
  RepairStatus.received: 'Received',
  RepairStatus.diagnosed: 'Diagnosed',
  RepairStatus.awaitingApproval: 'Awaiting Approval',
  RepairStatus.inRepair: 'In Repair',
  RepairStatus.qc: 'QC',
  RepairStatus.ready: 'Ready',
  RepairStatus.delivered: 'Delivered',
  RepairStatus.warrantyClaim: 'Warranty Claim',
  RepairStatus.cancelled: 'Cancelled',
};

/// Columns shown on the kanban board, in workflow order.
const repairBoardStatuses = [
  RepairStatus.received,
  RepairStatus.diagnosed,
  RepairStatus.awaitingApproval,
  RepairStatus.inRepair,
  RepairStatus.qc,
  RepairStatus.ready,
  RepairStatus.delivered,
];

Color repairStatusColor(RepairStatus s) {
  return switch (s) {
    RepairStatus.cancelled => AppColors.destructive,
    RepairStatus.warrantyClaim => AppColors.warning,
    RepairStatus.ready || RepairStatus.delivered => AppColors.success,
    _ => AppColors.accent,
  };
}

const repairPriorityLabels = {
  RepairPriority.low: 'Low',
  RepairPriority.normal: 'Normal',
  RepairPriority.high: 'High',
  RepairPriority.urgent: 'Urgent',
};

Color repairPriorityColor(RepairPriority p) {
  return switch (p) {
    RepairPriority.urgent => AppColors.destructive,
    RepairPriority.high => AppColors.warning,
    RepairPriority.normal => AppColors.accent,
    RepairPriority.low => AppColors.textMuted,
  };
}

class RepairStatusBadge extends StatelessWidget {
  const RepairStatusBadge({super.key, required this.status});
  final RepairStatus status;

  @override
  Widget build(BuildContext context) {
    final color = repairStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        repairStatusLabels[status]!,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class RepairPriorityChip extends StatelessWidget {
  const RepairPriorityChip({super.key, required this.priority});
  final RepairPriority priority;

  @override
  Widget build(BuildContext context) {
    final color = repairPriorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        repairPriorityLabels[priority]!,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
