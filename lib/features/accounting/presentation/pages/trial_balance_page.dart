import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../controllers/reports_controller.dart';
import '../widgets/report_filters.dart';

class TrialBalancePage extends ConsumerStatefulWidget {
  const TrialBalancePage({super.key});

  @override
  ConsumerState<TrialBalancePage> createState() => _TrialBalancePageState();
}

class _TrialBalancePageState extends ConsumerState<TrialBalancePage> {
  DateTime _asOf = DateTime.now();
  String? _branchId;

  @override
  Widget build(BuildContext context) {
    final report =
        ref.watch(trialBalanceProvider((asOf: _asOf, branchId: _branchId)));
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
        title: Text('Trial Balance', style: AppTypography.headline),
        actions: [
          PermissionGate(
            module: 'accounting',
            action: 'export',
            child: IconButton(
              icon: const Icon(Icons.ios_share,
                  color: AppColors.accent, size: 20),
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export coming soon'))),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
          children: [
            ReportDateChip(
                label: 'As of',
                value: _asOf,
                onPick: (d) => setState(() => _asOf = d)),
            const SizedBox(height: AppSpacing.sm),
            ReportBranchDropdown(
                value: _branchId,
                onChanged: (v) => setState(() => _branchId = v)),
            const SizedBox(height: AppSpacing.md),
            report.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => AppInlineBanner(
                  message: 'Could not load report.',
                  type: BannerType.error),
              data: (tb) => AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BalancedBadge(balanced: tb.balanced),
                      const Divider(
                          color: AppColors.separator, height: AppSpacing.xl),
                      if (tb.rows.isEmpty)
                        Text('No account activity.',
                            style: AppTypography.footnote
                                .copyWith(color: AppColors.textHint))
                      else
                        for (final r in tb.rows)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text('${r.code}  ${r.name}',
                                      style: AppTypography.footnote),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                      r.debit > 0 ? formatPkr(r.debit) : '',
                                      textAlign: TextAlign.right,
                                      style: AppTypography.footnote),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                      r.credit > 0 ? formatPkr(r.credit) : '',
                                      textAlign: TextAlign.right,
                                      style: AppTypography.footnote),
                                ),
                              ],
                            ),
                          ),
                      const Divider(
                          color: AppColors.separator, height: AppSpacing.xl),
                      _TotalRow('Total Debit', tb.totalDebit),
                      _TotalRow('Total Credit', tb.totalCredit),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}

class _BalancedBadge extends StatelessWidget {
  const _BalancedBadge({required this.balanced});
  final bool balanced;

  @override
  Widget build(BuildContext context) {
    final color = balanced ? AppColors.success : AppColors.destructive;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(balanced ? 'Balanced' : 'Unbalanced',
          style: AppTypography.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value);
  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.subhead),
          Text(formatPkr(value),
              style: AppTypography.subhead
                  .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
