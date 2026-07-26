import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/approval.dart';
import '../controllers/approvals_controller.dart';
import '../widgets/approval_ladder.dart';
import '../widgets/approval_timeline.dart';
import '../widgets/approvals_ui.dart';

class ApprovalDetailPage extends ConsumerWidget {
  const ApprovalDetailPage({super.key, required this.requestId});
  final String requestId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(approvalDetailProvider(requestId));

    return async.when(
      loading: () => const AppDetailScaffold(
        eyebrow: 'Approvals',
        title: 'Request',
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => AppDetailScaffold(
        eyebrow: 'Approvals',
        title: 'Request',
        child: AppErrorState(
          title: "Unable to load this request",
          body:
              "Unable to reach the server. Try again once you're back online.",
          onRetry: () => ref.invalidate(approvalDetailProvider(requestId)),
        ),
      ),
      data: (detail) => _DetailBody(detail: detail),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});
  final ApprovalDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final r = detail.request;
    final entityRoute = approvalEntityRoute(r.entityType, r.entityId);
    final entityNoun = approvalEntityNouns[r.entityType] ?? r.entityType;
    final title = r.reason?.trim().isNotEmpty == true
        ? r.reason!.trim()
        : (r.workflowName ?? approvalRequestType(r));
    final urgency = approvalUrgency(r);
    final stage = r.isOpen
        ? 'Level ${r.currentLevel} of ${detail.workflow.levelCount}'
        : 'Closed · ${detail.workflow.levelCount} of ${detail.workflow.levelCount} levels';

    return AppDetailScaffold(
      eyebrow: approvalRequestType(r),
      title: title,
      actions: [
        if (r.isOpen)
          AppPill(label: urgency.label, tone: urgency.tone)
        else
          AppPill(
            label: approvalStatusLabels[r.status]!,
            tone: approvalStatusTone(r.status),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Summary
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Two columns once the card is wide enough; else one.
                    final twoUp = constraints.maxWidth >= 440;
                    final cellW = twoUp
                        ? (constraints.maxWidth - 20) / 2
                        : constraints.maxWidth;
                    final cells = <(String, Widget)>[
                      (
                        'Amount',
                        r.amount != null
                            ? AppMoneyText(r.amount!, size: 19)
                            : _value('—', lum),
                      ),
                      ('Requested by', _value(r.requestorName ?? '—', lum)),
                      (
                        'Submitted',
                        _value(approvalDateShort(r.createdAt, withTime: true),
                            lum),
                      ),
                      ('Stage', _value(stage, lum)),
                    ];
                    return Wrap(
                      spacing: 20,
                      runSpacing: 18,
                      children: [
                        for (final (label, child) in cells)
                          SizedBox(
                            width: cellW,
                            child: _MetaCell(label: label, child: child),
                          ),
                      ],
                    );
                  },
                ),
                if (entityRoute != null) ...[
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppButton(
                      label: 'Open $entityNoun',
                      variant: AppButtonVariant.tinted,
                      size: AppButtonSize.sm,
                      icon: LucideIcons.externalLink,
                      // Repair lives in the nav shell, so it is entered with go;
                      // purchasing and HR are pushed as before.
                      onPressed: () => entityRoute.startsWith('/repair')
                          ? context.go(entityRoute)
                          : context.push(entityRoute),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Approval ladder
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Approval ladder', lum),
                const SizedBox(height: 16),
                ApprovalLadder(
                  workflow: detail.workflow,
                  request: r,
                  actions: detail.actions,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Activity
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle('Activity', lum),
                const SizedBox(height: 16),
                ApprovalTimeline(request: r, actions: detail.actions),
              ],
            ),
          ),

          if (r.isOpen) ...[
            const SizedBox(height: 14),
            _DecisionBar(request: r),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String label, LumColors lum) => Text(
        label,
        style: AppTypography.title3.copyWith(
          fontSize: 16,
          color: lum.textPrimary,
        ),
      );

  Widget _value(String v, LumColors lum) => Text(
        v,
        style: AppTypography.subhead.copyWith(color: lum.textPrimary),
      );
}

/// A labelled summary cell: an uppercase caption over its value. Width is set
/// by the parent from the card's measured constraints.
class _MetaCell extends StatelessWidget {
  const _MetaCell({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.caption.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: lum.g500,
          ),
        ),
        const SizedBox(height: 5),
        child,
      ],
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
      setState(() => _error = 'Add a comment before rejecting.');
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
    showAppToast(
      context,
      action == 'APPROVED' ? 'Approved · request advanced' : 'Rejected · requestor notified',
      type: BannerType.success,
    );
    Navigator.of(context).maybePop();
  }

  Future<void> _cancel() async {
    final reason =
        _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await ref
        .read(approvalActionsProvider)
        .cancel(requestId: widget.request.id, reason: reason);
    if (!mounted) return;
    setState(() => _busy = false);
    if (failure != null) {
      setState(() => _error = failure.message);
      return;
    }
    showAppToast(context, 'Request cancelled', type: BannerType.success);
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _commentCtrl,
            label: 'Comment',
            hint: 'Required to reject',
            prefixIcon: Icons.mode_comment_outlined,
            enabled: !_busy,
            errorText: _error,
          ),
          const SizedBox(height: 14),
          PermissionGate(
            module: 'approvals',
            action: 'approve',
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Approve',
                    icon: LucideIcons.check,
                    fullWidth: true,
                    loading: _busy,
                    onPressed: _busy ? null : () => _act('APPROVED'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: 'Reject',
                    variant: AppButtonVariant.destructive,
                    icon: LucideIcons.x,
                    fullWidth: true,
                    onPressed: _busy ? null : () => _act('REJECTED'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Cancel request',
            variant: AppButtonVariant.plain,
            fullWidth: true,
            onPressed: _busy ? null : _cancel,
          ),
        ],
      ),
    );
  }
}
