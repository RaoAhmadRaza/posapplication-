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

const _accounts = <String, String>{'1000': 'Cash', '1010': 'Bank'};

class CashBankBookPage extends ConsumerStatefulWidget {
  const CashBankBookPage({super.key});

  @override
  ConsumerState<CashBankBookPage> createState() => _CashBankBookPageState();
}

class _CashBankBookPageState extends ConsumerState<CashBankBookPage> {
  String _accountCode = '1000';
  late DateTime _from;
  DateTime _to = DateTime.now();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _from = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(cashBankBookProvider(
        (accountCode: _accountCode, from: _from, to: _to)));
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
        title: Text('Cash / Bank Book', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding, vertical: AppSpacing.md),
          children: [
            _AccountDropdown(
                value: _accountCode,
                onChanged: (v) => setState(() => _accountCode = v)),
            const SizedBox(height: AppSpacing.sm),
            ReportDateChip(
                label: 'From',
                value: _from,
                onPick: (d) => setState(() => _from = d)),
            const SizedBox(height: AppSpacing.sm),
            ReportDateChip(
                label: 'To', value: _to, onPick: (d) => setState(() => _to = d)),
            const SizedBox(height: AppSpacing.md),
            book.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => AppInlineBanner(
                  message: 'Could not load report.',
                  type: BannerType.error),
              data: (b) => AppCard(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Opening Balance',
                              style: AppTypography.footnote
                                  .copyWith(color: AppColors.textMuted)),
                          Text(formatPkr(b.openingBalance),
                              style: AppTypography.subhead),
                        ],
                      ),
                      const Divider(
                          color: AppColors.separator, height: AppSpacing.xl),
                      if (b.entries.isEmpty)
                        Text('No transactions in range.',
                            style: AppTypography.footnote
                                .copyWith(color: AppColors.textHint))
                      else
                        for (final e in b.entries)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          e.description ??
                                              e.entryNumber ??
                                              'Entry',
                                          style: AppTypography.footnote),
                                      Text(
                                          'Running: ${formatPkr(e.runningBalance)}',
                                          style: AppTypography.caption.copyWith(
                                              color: AppColors.textHint)),
                                    ],
                                  ),
                                ),
                                Text(
                                  e.debit > 0
                                      ? '+${formatPkr(e.debit)}'
                                      : '-${formatPkr(e.credit)}',
                                  style: AppTypography.footnote.copyWith(
                                      color: e.debit > 0
                                          ? AppColors.success
                                          : AppColors.destructive,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
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

class _AccountDropdown extends StatelessWidget {
  const _AccountDropdown({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.field),
        border: Border.all(color: AppColors.separator),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              size: 18, color: AppColors.textMuted),
          style: AppTypography.subhead,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: _accounts.entries
              .map((e) =>
                  DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
        ),
      ),
    );
  }
}
