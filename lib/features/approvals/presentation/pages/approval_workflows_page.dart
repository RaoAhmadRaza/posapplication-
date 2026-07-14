import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/approval.dart';
import '../controllers/workflows_controller.dart';
import '../widgets/approval_status_ui.dart';
import 'workflow_form_page.dart';

class ApprovalWorkflowsPage extends ConsumerWidget {
  const ApprovalWorkflowsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workflowsControllerProvider);

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
        title: Text('Approval Workflows', style: AppTypography.headline),
      ),
      floatingActionButton: PermissionGate(
        module: 'approvals',
        action: 'update',
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.accent,
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text('New',
              style: AppTypography.callout.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w600)),
          onPressed: () => _openForm(context),
        ),
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppInlineBanner(
                  message: 'Could not load workflows.',
                  type: BannerType.error),
            ),
          ),
          data: (rows) => _WorkflowsList(rows: rows),
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, [ApprovalWorkflow? wf]) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkflowFormPage(workflow: wf),
    ));
  }
}

class _WorkflowsList extends ConsumerWidget {
  const _WorkflowsList({required this.rows});
  final List<ApprovalWorkflow> rows;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (rows.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 60),
          Center(
            child: Padding(
              padding:
                  const EdgeInsets.all(AppSpacing.screenPadding),
              child: Text(
                'No workflows configured.\nA type with no active workflow '
                'needs no approval — it proceeds as normal.',
                textAlign: TextAlign.center,
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textMuted),
              ),
            ),
          ),
        ],
      );
    }
    // group by type, preserving the type-ordered fetch.
    final byType = <ApprovalWorkflowType, List<ApprovalWorkflow>>{};
    for (final w in rows) {
      byType.putIfAbsent(w.workflowType, () => []).add(w);
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: AppInlineBanner(
            message:
                'No active workflow for a type = that action needs no approval '
                '(proceeds as normal).',
            type: BannerType.info,
          ),
        ),
        for (final entry in byType.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
                top: AppSpacing.sm, bottom: AppSpacing.sm),
            child: Text(approvalTypeLabels[entry.key]!,
                style: AppTypography.footnote.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600)),
          ),
          for (final w in entry.value)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _WorkflowCard(workflow: w),
            ),
        ],
      ],
    );
  }
}

class _WorkflowCard extends ConsumerWidget {
  const _WorkflowCard({required this.workflow});
  final ApprovalWorkflow workflow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threshold = workflow.thresholdAmount == null
        ? 'Always'
        : '≥ ${formatPkr(workflow.thresholdAmount!)}';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => WorkflowFormPage(workflow: workflow),
              )),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(workflow.name,
                      style: AppTypography.subhead
                          .copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    '$threshold · ${workflow.levelCount} level(s) · '
                    'TTL ${workflow.escalationTtlHours}h',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          PermissionGate(
            module: 'approvals',
            action: 'update',
            child: Switch(
              value: workflow.isActive,
              activeThumbColor: AppColors.accent,
              onChanged: (v) => _toggle(context, ref, v),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(
      BuildContext context, WidgetRef ref, bool value) async {
    final failure = await ref
        .read(workflowsControllerProvider.notifier)
        .setActive(workflow, value);
    if (!context.mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}
