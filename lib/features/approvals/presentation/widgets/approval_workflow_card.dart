import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_toggle.dart';
import '../../domain/entities/approval.dart';
import 'approvals_ui.dart';

/// One workflow row: name + type over a "N levels · threshold" line, with an
/// active toggle for approvers or a read-only status pill for everyone else.
class ApprovalWorkflowCard extends StatelessWidget {
  const ApprovalWorkflowCard({
    super.key,
    required this.workflow,
    required this.canToggle,
    required this.onEdit,
    this.onToggle,
  });

  final ApprovalWorkflow workflow;
  final bool canToggle;
  final VoidCallback onEdit;
  final ValueChanged<bool>? onToggle;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final levelsText =
        '${workflow.levelCount} ${workflow.levelCount == 1 ? 'level' : 'levels'}';
    final thresholdText = workflow.thresholdAmount == null
        ? 'Always requires approval'
        : 'Over ${formatPkr(workflow.thresholdAmount!)}';

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onEdit,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Text(
                            workflow.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.title3.copyWith(
                              fontSize: 16,
                              color: lum.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          approvalTypeLabels[workflow.workflowType]!
                              .toUpperCase(),
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: lum.g500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$levelsText · $thresholdText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(color: lum.g500),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (canToggle)
            AppToggle(
              value: workflow.isActive,
              onChanged: onToggle,
              semanticLabel: '${workflow.name} active',
            )
          else
            AppPill(
              label: workflow.isActive ? 'Active' : 'Inactive',
              tone: workflow.isActive
                  ? AppPillTone.success
                  : AppPillTone.neutral,
            ),
        ],
      ),
    );
  }
}
