import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/fiscal_period.dart';
import '../../domain/failures/accounting_failure.dart';
import '../controllers/fiscal_periods_controller.dart';

class FiscalPeriodsPage extends ConsumerWidget {
  const FiscalPeriodsPage({super.key});

  Future<void> _close(
    BuildContext context,
    WidgetRef ref,
    FiscalPeriod period,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _CloseDialog(period: period),
    );
    if (confirmed != true) return;
    final failure =
        await ref.read(fiscalPeriodsProvider.notifier).close(period.id);
    if (!context.mounted) return;
    _notify(context, failure, 'Period closed');
  }

  Future<void> _reopen(
    BuildContext context,
    WidgetRef ref,
    FiscalPeriod period,
  ) async {
    final failure =
        await ref.read(fiscalPeriodsProvider.notifier).reopen(period.id);
    if (!context.mounted) return;
    _notify(context, failure, 'Period reopened');
  }

  void _notify(
    BuildContext context,
    AccountingFailure? failure,
    String success,
  ) {
    final message = failure?.message ?? success;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fiscalPeriodsProvider);

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
        title: Text('Fiscal Periods', style: AppTypography.headline),
      ),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(
            onRetry: () =>
                ref.read(fiscalPeriodsProvider.notifier).refresh(),
          ),
          data: (periods) => periods.isEmpty
              ? Center(
                  child: Text('No fiscal periods',
                      style: AppTypography.subhead
                          .copyWith(color: AppColors.textMuted)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPadding,
                      vertical: AppSpacing.md),
                  itemCount: periods.length,
                  itemBuilder: (_, i) => Padding(
                    padding: EdgeInsets.only(
                        bottom: i < periods.length - 1 ? AppSpacing.md : 0),
                    child: _PeriodCard(
                      period: periods[i],
                      onClose: () => _close(context, ref, periods[i]),
                      onReopen: () => _reopen(context, ref, periods[i]),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  const _PeriodCard({
    required this.period,
    required this.onClose,
    required this.onReopen,
  });

  final FiscalPeriod period;
  final VoidCallback onClose;
  final VoidCallback onReopen;

  String _day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}'
      '-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(period.name, style: AppTypography.headline),
              ),
              _StatusChip(status: period.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text('${_day(period.startDate)} – ${_day(period.endDate)}',
              style: AppTypography.footnote
                  .copyWith(color: AppColors.textMuted)),
          if (period.status != FiscalPeriodStatus.locked) ...[
            const SizedBox(height: AppSpacing.md),
            PermissionGate(
              module: 'accounting',
              action: 'approve',
              child: period.status == FiscalPeriodStatus.open
                  ? AppButton(
                      label: 'Close',
                      variant: AppButtonVariant.destructive,
                      onPressed: onClose,
                    )
                  : AppButton(
                      label: 'Reopen',
                      variant: AppButtonVariant.tinted,
                      onPressed: onReopen,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final FiscalPeriodStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      FiscalPeriodStatus.open => ('OPEN', AppColors.success),
      FiscalPeriodStatus.closed => ('CLOSED', AppColors.textMuted),
      FiscalPeriodStatus.locked => ('LOCKED', AppColors.destructive),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Text(label,
          style: AppTypography.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _CloseDialog extends StatelessWidget {
  const _CloseDialog({required this.period});
  final FiscalPeriod period;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.background,
      title: Text('Close ${period.name}?', style: AppTypography.headline),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (period.isCurrent) ...[
            AppInlineBanner(
              message: 'This is the current period — new sales, payments, '
                  'and journals will be REJECTED until it is reopened.',
              type: BannerType.error,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text('Closing locks new postings dated within this period.',
              style: AppTypography.subhead
                  .copyWith(color: AppColors.textMuted)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Close Period'),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppInlineBanner(
                message: 'Could not load fiscal periods.',
                type: BannerType.error),
            const SizedBox(height: AppSpacing.md),
            AppButton(label: 'Retry', onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
