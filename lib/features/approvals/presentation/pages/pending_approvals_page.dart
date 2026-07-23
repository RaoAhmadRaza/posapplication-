import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/approval.dart';
import '../controllers/approvals_controller.dart';
import '../widgets/approval_request_card.dart';
import '../widgets/approvals_ui.dart';

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
    final lum = context.lum;
    final async = ref.watch(pendingApprovalsControllerProvider);

    final labels = ['All', for (final t in ApprovalWorkflowType.values) approvalTypeLabels[t]!];
    final selected = _type == null
        ? 0
        : ApprovalWorkflowType.values.indexOf(_type!) + 1;

    return ModuleScaffold(
      title: 'Approvals',
      maxContentWidth: 720,
      actions: [
        _HeaderAction(
          icon: LucideIcons.history,
          tooltip: 'History',
          onTap: () => context.push('/approvals/history'),
        ),
        PermissionGate(
          module: 'approvals',
          action: 'update',
          child: _HeaderAction(
            icon: LucideIcons.settings,
            tooltip: 'Configure workflows',
            onTap: () => context.push('/approvals/workflows'),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
            child: AppFilterChips(
              labels: labels,
              selected: selected,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              onSelected: (i) => setState(
                () => _type =
                    i == 0 ? null : ApprovalWorkflowType.values[i - 1],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: lum.accent,
              onRefresh: () => ref
                  .read(pendingApprovalsControllerProvider.notifier)
                  .refresh(),
              child: async.when(
                loading: () => const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: AppListSkeleton(rows: 4, rowHeight: 118),
                ),
                error: (e, _) => _scrollable(
                  AppErrorState(
                    title: "We couldn't load approvals",
                    body:
                        "We couldn't reach the server. Nothing is lost — pull to refresh once you're back online.",
                    onRetry: () => ref
                        .read(pendingApprovalsControllerProvider.notifier)
                        .refresh(),
                  ),
                ),
                data: (rows) {
                  final list = _type == null
                      ? rows
                      : rows.where((r) => r.workflowType == _type).toList();
                  if (list.isEmpty) {
                    return _scrollable(
                      AppEmptyState(
                        icon: LucideIcons.checkCheck,
                        title: _type == null
                            ? "You're all caught up"
                            : 'Nothing of this type',
                        body: _type == null
                            ? 'No approvals are waiting right now. New requests show up here.'
                            : 'No pending approvals match this filter.',
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        ApprovalRequestCard(request: list[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Wraps a centred state so pull-to-refresh still works when the list is empty
  /// or errored (a bare Center is not scrollable).
  Widget _scrollable(Widget child) => LayoutBuilder(
        builder: (context, constraints) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
              child: Center(child: child),
            ),
          ],
        ),
      );
}

/// A 40x40 clear icon button for the module header.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return IconButton(
      icon: Icon(icon, size: 20, color: lum.g600),
      tooltip: tooltip,
      onPressed: onTap,
    );
  }
}
