import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_text_field.dart';
import '../../domain/entities/approval.dart';
import '../controllers/approvals_controller.dart';
import '../widgets/approval_status_ui.dart';
import 'pending_approvals_page.dart';

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
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(approvalHistoryProvider);

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
        title: Text('Approval History', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppTextField(
                controller: _searchCtrl,
                label: 'Search by type or entity',
                prefixIcon: Icons.search,
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: async.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding:
                        const EdgeInsets.all(AppSpacing.screenPadding),
                    child: AppInlineBanner(
                        message: 'Could not load history.',
                        type: BannerType.error),
                  ),
                ),
                data: (rows) {
                  final list = _query.isEmpty
                      ? rows
                      : rows.where(_matches).toList();
                  if (list.isEmpty) {
                    return Center(
                      child: Text('No completed requests.',
                          style: AppTypography.footnote
                              .copyWith(color: AppColors.textMuted)),
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
          ],
        ),
      ),
    );
  }

  bool _matches(ApprovalRequest r) {
    final type = r.workflowType == null
        ? ''
        : approvalTypeLabels[r.workflowType]!.toLowerCase();
    return r.entityType.toLowerCase().contains(_query) ||
        type.contains(_query);
  }
}
