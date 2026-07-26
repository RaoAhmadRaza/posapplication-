import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_list_skeleton.dart';
import '../../../../core/design/widgets/app_search_field.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../domain/entities/approval.dart';
import '../controllers/approvals_controller.dart';
import '../widgets/approval_request_card.dart';
import '../widgets/approvals_ui.dart';

class ApprovalHistoryPage extends ConsumerStatefulWidget {
  const ApprovalHistoryPage({super.key});

  @override
  ConsumerState<ApprovalHistoryPage> createState() =>
      _ApprovalHistoryPageState();
}

class _ApprovalHistoryPageState extends ConsumerState<ApprovalHistoryPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.trim().toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(approvalHistoryProvider);

    return AppDetailScaffold(
      eyebrow: 'Approvals',
      title: 'History',
      maxContentWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSearchField(
            controller: _searchCtrl,
            hint: 'Search by type or entity…',
            onClear: () => setState(() => _query = ''),
          ),
          const SizedBox(height: 16),
          async.when(
            loading: () => const AppListSkeleton(rows: 4, rowHeight: 96),
            error: (e, _) => AppErrorState(
              title: "Unable to load history",
              body:
                  "Unable to reach the server. Try again once you're back online.",
              onRetry: () => ref.invalidate(approvalHistoryProvider),
            ),
            data: (rows) {
              final list =
                  _query.isEmpty ? rows : rows.where(_matches).toList();
              if (list.isEmpty) {
                return AppEmptyState(
                  icon:
                      _query.isEmpty ? LucideIcons.checkCheck : LucideIcons.searchX,
                  title: _query.isEmpty
                      ? 'No completed requests'
                      : 'Nothing matches that search',
                  body: _query.isEmpty
                      ? 'Approved, rejected and cancelled requests land here.'
                      : 'Try a workflow type like "refund" or an entity name.',
                );
              }
              return Column(
                children: [
                  for (final r in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ApprovalRequestCard(request: r),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  bool _matches(ApprovalRequest r) {
    final type = r.workflowType == null
        ? ''
        : approvalTypeLabels[r.workflowType]!.toLowerCase();
    final reason = r.reason?.toLowerCase() ?? '';
    return r.entityType.toLowerCase().contains(_query) ||
        type.contains(_query) ||
        reason.contains(_query);
  }
}
