import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_confirm_dialog.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/fiscal_period.dart';
import '../../domain/failures/accounting_failure.dart';
import '../controllers/fiscal_periods_controller.dart';
import '../widgets/acct_date_field.dart';
import '../widgets/accounting_ui.dart';

class FiscalPeriodsPage extends ConsumerWidget {
  const FiscalPeriodsPage({super.key});

  Future<void> _close(
    BuildContext context,
    WidgetRef ref,
    FiscalPeriod period,
  ) async {
    final confirmed = await showAppConfirm(
      context,
      title: 'Close period?',
      message: 'This stops new postings in ${period.name} until it is '
          'reopened. You can reopen it later if you need to make an adjustment.',
      confirmLabel: 'Close period',
      destructive: true,
    );
    if (!confirmed) return;
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
    if (failure != null) {
      showAppToast(context, failure.message, type: BannerType.error);
      return;
    }
    showAppToast(context, success, type: BannerType.success);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(fiscalPeriodsProvider);

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'Fiscal periods',
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => AppErrorState(
          title: 'Couldn\'t load periods',
          body: 'Your data is safe. Check the connection and try again.',
          onRetry: () => ref.read(fiscalPeriodsProvider.notifier).refresh(),
        ),
        data: (periods) => periods.isEmpty
            ? const AppEmptyState(
                icon: LucideIcons.calendarRange,
                title: 'No periods yet',
                body: 'Fiscal periods will appear here once configured.',
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < periods.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _PeriodRow(
                      period: periods[i],
                      onClose: () => _close(context, ref, periods[i]),
                      onReopen: () => _reopen(context, ref, periods[i]),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({
    required this.period,
    required this.onClose,
    required this.onReopen,
  });

  final FiscalPeriod period;
  final VoidCallback onClose;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    final (IconData icon, Color bg, Color fg) = switch (period.status) {
      FiscalPeriodStatus.open => (
          LucideIcons.calendarCheck,
          lum.accentSoft,
          lum.accent,
        ),
      FiscalPeriodStatus.closed => (
          LucideIcons.calendarX,
          lum.surface2,
          lum.g500,
        ),
      FiscalPeriodStatus.locked => (
          LucideIcons.lock,
          lum.surface2,
          lum.g600,
        ),
    };

    final (String pillLabel, AppPillTone pillTone) = switch (period.status) {
      FiscalPeriodStatus.open => ('Open', AppPillTone.lumen),
      FiscalPeriodStatus.closed => ('Closed', AppPillTone.neutral),
      FiscalPeriodStatus.locked => ('Locked', AppPillTone.neutral),
    };

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          AcctIconTile(icon: icon, background: bg, foreground: fg),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  period.name,
                  style: AppTypography.headline.copyWith(fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '${acctFormatDate(period.startDate)} – '
                  '${acctFormatDate(period.endDate)}',
                  style: AppTypography.subhead
                      .copyWith(fontSize: 12.5, color: lum.g500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppPill(label: pillLabel, tone: pillTone),
          if (period.status != FiscalPeriodStatus.locked) ...[
            const SizedBox(width: 10),
            PermissionGate(
              module: 'accounting',
              action: 'approve',
              child: period.status == FiscalPeriodStatus.open
                  ? AppButton(
                      label: 'Close',
                      variant: AppButtonVariant.destructive,
                      size: AppButtonSize.sm,
                      onPressed: onClose,
                    )
                  : AppButton(
                      label: 'Reopen',
                      variant: AppButtonVariant.tinted,
                      size: AppButtonSize.sm,
                      onPressed: onReopen,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
