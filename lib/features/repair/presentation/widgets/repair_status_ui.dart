import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/widgets/app_pill.dart';
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

/// Semantic tone of a status, per the design's column/pill tone table.
AppPillTone repairStatusTone(RepairStatus s) => switch (s) {
      RepairStatus.received => AppPillTone.neutral,
      RepairStatus.diagnosed ||
      RepairStatus.inRepair ||
      RepairStatus.qc =>
        AppPillTone.lumen,
      RepairStatus.awaitingApproval => AppPillTone.warning,
      RepairStatus.ready || RepairStatus.delivered => AppPillTone.success,
      RepairStatus.warrantyClaim => AppPillTone.transit,
      RepairStatus.cancelled => AppPillTone.danger,
    };

/// Solid colour for a tone — the board's column dot and the timeline's node.
Color repairToneColor(BuildContext context, AppPillTone tone) {
  final lum = context.lum;
  return switch (tone) {
    AppPillTone.neutral => lum.g400,
    AppPillTone.lumen => lum.accent,
    AppPillTone.success => lum.success,
    AppPillTone.warning => lum.warning,
    AppPillTone.danger => lum.danger,
    AppPillTone.transit => lum.transit,
  };
}

Color repairStatusColor(BuildContext context, RepairStatus s) =>
    repairToneColor(context, repairStatusTone(s));

const repairPriorityLabels = {
  RepairPriority.low: 'Low',
  RepairPriority.normal: 'Normal',
  RepairPriority.high: 'High',
  RepairPriority.urgent: 'Urgent',
};

AppPillTone repairPriorityTone(RepairPriority p) => switch (p) {
      RepairPriority.urgent => AppPillTone.danger,
      RepairPriority.high => AppPillTone.warning,
      RepairPriority.normal || RepairPriority.low => AppPillTone.neutral,
    };

Color repairPriorityColor(BuildContext context, RepairPriority p) =>
    repairToneColor(context, repairPriorityTone(p));

class RepairStatusBadge extends StatelessWidget {
  const RepairStatusBadge({super.key, required this.status, this.showDot = true});

  final RepairStatus status;
  final bool showDot;

  @override
  Widget build(BuildContext context) => AppPill(
        label: repairStatusLabels[status]!,
        tone: repairStatusTone(status),
        showDot: showDot,
      );
}

class RepairPriorityChip extends StatelessWidget {
  const RepairPriorityChip({super.key, required this.priority, this.suffix});

  final RepairPriority priority;

  /// Appended to the label, e.g. ' priority' on the detail header.
  final String? suffix;

  @override
  Widget build(BuildContext context) => AppPill(
        label: '${repairPriorityLabels[priority]!}${suffix ?? ''}',
        tone: repairPriorityTone(priority),
        // The design dots only the two urgent tones.
        showDot: priority == RepairPriority.urgent ||
            priority == RepairPriority.high,
      );
}
