import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/approval.dart';
import '../controllers/approvals_controller.dart';
import '../widgets/approval_status_ui.dart';

class ApprovalDetailPage extends ConsumerWidget {
  const ApprovalDetailPage({super.key, required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(approvalDetailProvider(requestId));

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
        title: Text('Request', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppInlineBanner(
                  message: 'Could not load this request.',
                  type: BannerType.error),
            ),
          ),
          data: (detail) => _DetailBody(detail: detail),
        ),
      ),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});
  final ApprovalDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = detail.request;
    final entityRoute = approvalEntityRoute(r.entityType, r.entityId);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        // Summary
        Container(
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
                    child: Text(
                      r.workflowType == null
                          ? r.entityType
                          : approvalTypeLabels[r.workflowType]!,
                      style: AppTypography.title2
                          .copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  ApprovalStatusBadge(status: r.status),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              _row('Entity', '${r.entityType} · ${r.entityId}'),
              if (r.amount != null) _row('Amount', formatPkr(r.amount!)),
              _row('Requested by', r.requestorName ?? '—'),
              _row('Level', '${r.currentLevel} of ${detail.workflow.levelCount}'),
              if (r.reason != null && r.reason!.isNotEmpty)
                _row('Reason', r.reason!),
              if (entityRoute != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Open ${r.entityType}',
                  variant: AppButtonVariant.tinted,
                  onPressed: () => context.push(entityRoute),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Level ladder
        Text('Approval ladder',
            style: AppTypography.footnote.copyWith(
                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        for (final l in detail.workflow.levels)
          _LadderRow(level: l, currentLevel: r.currentLevel, status: r.status),
        const SizedBox(height: AppSpacing.lg),

        // Timeline
        Text('History',
            style: AppTypography.footnote.copyWith(
                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: AppSpacing.sm),
        if (detail.actions.isEmpty)
          Text('No actions yet.',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textMuted))
        else
          for (final a in detail.actions) _TimelineRow(action: a),

        const SizedBox(height: AppSpacing.lg),

        // Decision buttons (open requests only)
        if (r.isOpen) _DecisionBar(request: r),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: AppTypography.caption
                    .copyWith(color: AppColors.textMuted)),
          ),
          Expanded(
            child: Text(value, style: AppTypography.subhead),
          ),
        ],
      ),
    );
  }
}

class _LadderRow extends StatelessWidget {
  const _LadderRow({
    required this.level,
    required this.currentLevel,
    required this.status,
  });
  final ApprovalLevel level;
  final int currentLevel;
  final ApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final done = level.level < currentLevel ||
        status == ApprovalStatus.approved;
    final active = level.level == currentLevel &&
        (status == ApprovalStatus.pending ||
            status == ApprovalStatus.escalated);
    final color = done
        ? AppColors.success
        : active
            ? AppColors.accent
            : AppColors.textMuted;
    final icon = done
        ? Icons.check_circle
        : active
            ? Icons.radio_button_checked
            : Icons.radio_button_unchecked;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Text('Level ${level.level}',
              style: AppTypography.subhead
                  .copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '${level.requiredRole} · ${level.minApprovers} approver(s)',
              style: AppTypography.caption
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.action});
  final ApprovalAction action;

  @override
  Widget build(BuildContext context) {
    final color = approvalActionColor(action.action);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${action.action} · Level ${action.level}',
                  style: AppTypography.subhead.copyWith(
                      color: color, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${action.actorName ?? '—'} · '
                  '${action.actedAt.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}',
                  style: AppTypography.caption
                      .copyWith(color: AppColors.textMuted),
                ),
                if (action.comments != null && action.comments!.isNotEmpty)
                  Text(action.comments!,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionBar extends ConsumerStatefulWidget {
  const _DecisionBar({required this.request});
  final ApprovalRequest request;

  @override
  ConsumerState<_DecisionBar> createState() => _DecisionBarState();
}

class _DecisionBarState extends ConsumerState<_DecisionBar> {
  final _commentCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _act(String action) async {
    final comments =
        _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim();
    if (action == 'REJECTED' && comments == null) {
      setState(() => _error = 'A reason is required to reject.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await ref.read(approvalActionsProvider).act(
          requestId: widget.request.id,
          action: action,
          comments: comments,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      setState(() => _error = failure.message);
      return;
    }
    _commentCtrl.clear();
  }

  Future<void> _cancel() async {
    final reason = _commentCtrl.text.trim().isEmpty
        ? null
        : _commentCtrl.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await ref
        .read(approvalActionsProvider)
        .cancel(requestId: widget.request.id, reason: reason);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) setState(() => _error = failure.message);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
            controller: _commentCtrl,
            label: 'Comments (required to reject)',
            prefixIcon: Icons.notes),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppInlineBanner(message: _error!, type: BannerType.error),
        ],
        const SizedBox(height: AppSpacing.md),
        PermissionGate(
          module: 'approvals',
          action: 'approve',
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Approve',
                  variant: AppButtonVariant.tinted,
                  loading: _busy,
                  onPressed: _busy ? null : () => _act('APPROVED'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Reject',
                  variant: AppButtonVariant.plain,
                  onPressed: _busy ? null : () => _act('REJECTED'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Cancel request',
          variant: AppButtonVariant.plain,
          onPressed: _busy ? null : _cancel,
        ),
      ],
    );
  }
}
