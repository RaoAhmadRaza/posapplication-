import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../controllers/reports_controller.dart';
import '../widgets/report_filters.dart';

class BalanceSheetPage extends ConsumerStatefulWidget {
  const BalanceSheetPage({super.key});

  @override
  ConsumerState<BalanceSheetPage> createState() => _BalanceSheetPageState();
}

class _BalanceSheetPageState extends ConsumerState<BalanceSheetPage> {
  DateTime _asOf = DateTime.now();
  String? _branchId;

  @override
  Widget build(BuildContext context) {
    final report =
        ref.watch(balanceSheetProvider((asOf: _asOf, branchId: _branchId)));
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
        title: Text('Balance Sheet', style: AppTypography.headline),
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
              data: (bs) {
                final claims = bs.liabilities + bs.equity + bs.retainedEarnings;
                return AppCard(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _badge(bs.balanced),
                        const Divider(
                            color: AppColors.separator, height: AppSpacing.xl),
                        _row('Assets', bs.assets, emphasize: true),
                        const SizedBox(height: AppSpacing.sm),
                        _row('Liabilities', bs.liabilities),
                        _row('Equity', bs.equity),
                        _row('Retained Earnings', bs.retainedEarnings),
                        const Divider(
                            color: AppColors.separator, height: AppSpacing.xl),
                        _row('Liabilities + Equity', claims, emphasize: true),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  Widget _badge(bool balanced) {
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

  Widget _row(String label, double value, {bool emphasize = false}) {
    final style = emphasize
        ? AppTypography.headline
        : AppTypography.subhead.copyWith(color: AppColors.textMuted);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text(formatPkr(value),
              style: style.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
