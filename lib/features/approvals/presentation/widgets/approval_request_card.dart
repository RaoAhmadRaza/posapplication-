import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/approval.dart';
import 'approvals_ui.dart';

/// One request card, used by both the pending list and the history list. The
/// layout follows the design: an open request leads with an urgency pill and a
/// status pill; a closed request shows its outcome pill in the header and its
/// settled date beside the amount.
class ApprovalRequestCard extends StatelessWidget {
  const ApprovalRequestCard({super.key, required this.request});

  final ApprovalRequest request;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final open = request.isOpen;
    final typeLabel = approvalRequestType(request);
    // No friendly entity number exists in the backend — the workflow name and
    // reason are the real human labels for what is being approved.
    final title = request.reason?.trim().isNotEmpty == true
        ? request.reason!.trim()
        : (request.workflowName ?? typeLabel);
    final urgency = approvalUrgency(request);

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      onTap: () => context.push('/approvals/${request.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _eyebrow(typeLabel, lum)),
              if (open)
                AppPill(label: urgency.label, tone: urgency.tone)
              else
                AppPill(
                  label: approvalStatusLabels[request.status]!,
                  tone: approvalStatusTone(request.status),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.title3.copyWith(
              fontSize: 16,
              color: lum.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: _meta(context, lum, open)),
              if (open)
                AppPill(
                  label: approvalStatusLabels[request.status]!,
                  tone: approvalStatusTone(request.status),
                )
              else if (request.amount != null)
                AppMoneyText(request.amount!, size: 15, color: lum.g700),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eyebrow(String label, LumColors lum) => Text(
        label.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.caption.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: lum.g500,
        ),
      );

  Widget _meta(BuildContext context, LumColors lum, bool open) {
    final requestor = request.requestorName ?? '—';
    if (open) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (request.amount != null) ...[
            AppMoneyText(request.amount!, size: 17),
            const SizedBox(height: 4),
          ],
          Text(
            '$requestor · Level ${request.currentLevel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: lum.g500),
          ),
        ],
      );
    }
    // Closed row: requestor · settled date under the title, amount on the right.
    return Text(
      '$requestor · ${approvalDateShort(request.completedAt)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTypography.caption.copyWith(color: lum.g500),
    );
  }
}
