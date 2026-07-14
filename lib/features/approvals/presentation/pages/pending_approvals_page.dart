import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/approval.dart';
import '../controllers/approvals_controller.dart';
import '../widgets/approval_status_ui.dart';

class PendingApprovalsPage extends ConsumerStatefulWidget {
  const PendingApprovalsPage({super.key});

  @override
  ConsumerState<PendingApprovalsPage> createState() =>
      _PendingApprovalsPageState();
}

class _PendingApprovalsPageState extends ConsumerState<PendingApprovalsPage> {
  ApprovalWorkflowType? _type;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(pendingApprovalsControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios,
              color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Approvals', style: AppTypography.headline),
        actions: [
          PermissionGate(
            module: 'approvals',
            action: 'update',
            child: IconButton(
              icon: const Icon(Icons.settings_outlined,
                  color: AppColors.accent),
              onPressed: () => context.push('/approvals/workflows'),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.accent),
            onPressed: () => context.push('/approvals/history'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding),
                children: [
                  _chip('All', _type == null, () => setState(() => _type = null)),
                  for (final t in ApprovalWorkflowType.values)
                    _chip(approvalTypeLabels[t]!, _type == t,
                        () => setState(() => _type = t)),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(pendingApprovalsControllerProvider.notifier).refresh(),
                child: async.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ListView(
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.all(AppSpacing.screenPadding),
                        child: AppInlineBanner(
                            message: 'Could not load approvals.',
                            type: BannerType.error),
                      ),
                    ],
                  ),
                  data: (rows) {
                    final list = _type == null
                        ? rows
                        : rows.where((r) => r.workflowType == _type).toList();
                    if (list.isEmpty) {
                      return ListView(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 80),
                            child: Center(
                              child: Text('Nothing awaiting approval.',
                                  style: AppTypography.footnote
                                      .copyWith(color: AppColors.textMuted)),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.screenPadding),
                      children: [
                        for (final r in list)
                          Padding(
                            padding:
                                const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: ApprovalRequestCard(request: r),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.accent
                : AppColors.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label,
              style: AppTypography.footnote.copyWith(
                  color: selected ? Colors.white : AppColors.accent,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

/// One request card, used by both the pending list and history list.
class ApprovalRequestCard extends StatelessWidget {
  const ApprovalRequestCard({super.key, required this.request});
  final ApprovalRequest request;

  @override
  Widget build(BuildContext context) {
    final typeLabel = request.workflowType == null
        ? request.entityType
        : approvalTypeLabels[request.workflowType]!;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.card),
      onTap: () => context.push('/approvals/${request.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.separator, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(typeLabel,
                      style: AppTypography.subhead
                          .copyWith(fontWeight: FontWeight.w600)),
                ),
                ApprovalStatusBadge(status: request.status),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(request.entityType,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted)),
                if (request.amount != null) ...[
                  Text('  ·  ',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted)),
                  Text(formatPkr(request.amount!),
                      style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600)),
                ],
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'By ${request.requestorName ?? '—'} · Level ${request.currentLevel}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ),
                Text(_ageLabel(request),
                    style: AppTypography.caption.copyWith(
                        color: _ageColor(request),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _ageLabel(ApprovalRequest r) {
  if (r.status == ApprovalStatus.escalated) return 'Escalated';
  final expires = r.expiresAt;
  if (expires != null && r.isOpen) {
    final left = expires.difference(DateTime.now());
    if (left.isNegative) return 'Overdue';
    if (left.inHours < 6) return 'Due soon';
  }
  final age = DateTime.now().difference(r.createdAt);
  if (age.inDays >= 1) return '${age.inDays}d ago';
  if (age.inHours >= 1) return '${age.inHours}h ago';
  return '${age.inMinutes}m ago';
}

Color _ageColor(ApprovalRequest r) {
  final label = _ageLabel(r);
  if (label == 'Escalated' || label == 'Overdue' || label == 'Due soon') {
    return AppColors.destructive;
  }
  return AppColors.textMuted;
}
