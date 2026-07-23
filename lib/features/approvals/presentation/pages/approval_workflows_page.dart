import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/permission_controller.dart';
import '../../domain/entities/approval.dart';
import '../controllers/workflows_controller.dart';
import '../widgets/approval_workflow_card.dart';
import 'workflow_form_page.dart';

class ApprovalWorkflowsPage extends ConsumerWidget {
  const ApprovalWorkflowsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workflowsControllerProvider);
    final canUpdate = ref
            .watch(permissionMatrixProvider)
            .value
            ?.contains('approvals:update') ??
        false;

    return AppDetailScaffold(
      eyebrow: 'Approvals',
      title: 'Workflows',
      maxContentWidth: 720,
      actions: [
        PermissionGate(
          module: 'approvals',
          action: 'update',
          child: AppButton(
            label: 'New workflow',
            icon: LucideIcons.plus,
            size: AppButtonSize.sm,
            onPressed: () => _openForm(context),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: AppInlineBanner(
              message:
                  'A type with no active workflow skips approval entirely — '
                  'those requests are auto-approved. Toggle one on to start routing.',
              type: BannerType.info,
            ),
          ),
          async.when(
            loading: () => const AppListSkeleton(rows: 4, rowHeight: 80),
            error: (e, _) => AppErrorState(
              title: "We couldn't load workflows",
              body:
                  "We couldn't reach the server. Try again once you're back online.",
              onRetry: () => ref.invalidate(workflowsControllerProvider),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return const AppEmptyState(
                  icon: LucideIcons.gitBranch,
                  title: 'No workflows yet',
                  body:
                      'Create one to route a request type through an approval ladder.',
                );
              }
              return Column(
                children: [
                  for (final w in rows)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ApprovalWorkflowCard(
                        workflow: w,
                        canToggle: canUpdate,
                        onEdit: () => _openForm(context, w),
                        onToggle: (v) => _toggle(context, ref, w, v),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openForm(BuildContext context, [ApprovalWorkflow? wf]) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkflowFormPage(workflow: wf),
    ));
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    ApprovalWorkflow workflow,
    bool value,
  ) async {
    final failure = await ref
        .read(workflowsControllerProvider.notifier)
        .setActive(workflow, value);
    if (!context.mounted) return;
    if (failure != null) {
      showAppToast(context, failure.message, type: BannerType.error);
    }
  }
}
