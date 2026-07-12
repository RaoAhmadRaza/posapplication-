import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../controllers/reports_controller.dart';
import '../widgets/report_filters.dart';

class ProfitLossPage extends ConsumerStatefulWidget {
  const ProfitLossPage({super.key});

  @override
  ConsumerState<ProfitLossPage> createState() => _ProfitLossPageState();
}

class _ProfitLossPageState extends ConsumerState<ProfitLossPage> {
  late DateTime _from;
  DateTime _to = DateTime.now();
  String? _branchId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(
        profitLossProvider((from: _from, to: _to, branchId: _branchId)));
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
        title: Text('Profit & Loss', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
          children: [
            ReportDateChip(
                label: 'From',
                value: _from,
                onPick: (d) => setState(() => _from = d)),
            const SizedBox(height: AppSpacing.sm),
            ReportDateChip(
                label: 'To',
                value: _to,
                onPick: (d) => setState(() => _to = d)),
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
              data: (pl) => AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      _Row('Revenue', pl.revenue, AppColors.textPrimary),
                      _Row('Expenses', pl.expenses, AppColors.textPrimary),
                      const Divider(
                          color: AppColors.separator, height: AppSpacing.xl),
                      _Row(
                        'Net Profit',
                        pl.netProfit,
                        pl.netProfit >= 0
                            ? AppColors.success
                            : AppColors.destructive,
                        emphasize: true,
                      ),
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

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, this.color, {this.emphasize = false});
  final String label;
  final double value;
  final Color color;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
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
              style: style.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
