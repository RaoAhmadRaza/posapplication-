import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/payroll.dart';
import '../../domain/failures/hr_failure.dart';
import '../../data/services/payslip_pdf_service.dart';
import '../controllers/payroll_controller.dart';
import '../widgets/hr_status_ui.dart';

class PayrollRunDetailPage extends ConsumerWidget {
  const PayrollRunDetailPage({super.key, required this.runId});
  final String runId;

  static const _payAccount = '1000'; // Cash — mirrors H5 default

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(payrollRunDetailProvider(runId));
    final employer = ref.watch(currentBranchProvider)?.name ?? 'Payslip';

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
        title: Text('Payroll Run', style: AppTypography.headline),
        actions: [
          async.maybeWhen(
            data: (d) => d.items.isEmpty
                ? const SizedBox()
                : IconButton(
                    icon: const Icon(Icons.print_outlined,
                        color: AppColors.accent),
                    tooltip: 'Print all payslips',
                    onPressed: () => Printing.layoutPdf(
                      onLayout: (_) => PayslipPdfService().generateAll(
                          items: d.items, run: d.run, employerName: employer),
                    ),
                  ),
            orElse: () => const SizedBox(),
          ),
        ],
      ),
      body: SafeArea(
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: AppInlineBanner(
                  message: 'Could not load the run.', type: BannerType.error),
            ),
          ),
          data: (detail) => _Body(
              runId: runId, detail: detail, employer: employer),
        ),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body(
      {required this.runId, required this.detail, required this.employer});
  final String runId;
  final PayrollRunDetail detail;
  final String employer;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  bool _busy = false;
  String? _error;

  PayrollRun get _run => widget.detail.run;

  Future<void> _run3(Future<HrFailure?> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final failure = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (failure != null) _error = failure.message;
    });
  }

  Future<void> _calculate() =>
      _run3(() => ref.read(payrollActionsProvider).calculate(widget.runId));

  Future<void> _approve() =>
      _run3(() => ref.read(payrollActionsProvider).approve(widget.runId));

  Future<void> _disburse() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('Disburse payroll', style: AppTypography.headline),
        content: Text(
            'Pay ${formatPkr(_run.totalNet)} net to account '
            '${PayrollRunDetailPage._payAccount} (Cash) and post the journal?',
            style: AppTypography.body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Disburse')),
        ],
      ),
    );
    if (ok != true) return;
    await _run3(() => ref.read(payrollActionsProvider).disburse(
        widget.runId, PayrollRunDetailPage._payAccount));
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.detail.items;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_run.period, style: AppTypography.title2),
                  Text(
                      '${_run.startDate.toIso8601String().substring(0, 10)} → '
                      '${_run.endDate.toIso8601String().substring(0, 10)}',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            HrStatusBadge(
                label: payrollStatusLabels[_run.status]!,
                color: payrollStatusColor(_run.status)),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _totals(),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          AppInlineBanner(message: _error!, type: BannerType.error),
        ],
        const SizedBox(height: AppSpacing.md),
        _actions(),
        const SizedBox(height: AppSpacing.lg),
        if (items.isEmpty)
          Center(
            child: Text(
                _run.status == PayrollStatus.draft
                    ? 'Calculate to generate items.'
                    : 'No items.',
                style: AppTypography.footnote
                    .copyWith(color: AppColors.textMuted)),
          )
        else
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ItemRow(item: it, run: _run, employer: widget.employer),
            ),
      ],
    );
  }

  Widget _totals() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _stat('Gross', _run.totalGross),
          _stat('Deductions', _run.totalDeductions),
          _stat('Net', _run.totalNet),
        ],
      ),
    );
  }

  Widget _stat(String label, double value) => Column(
        children: [
          Text(label,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(formatPkr(value),
              style: AppTypography.footnote
                  .copyWith(fontWeight: FontWeight.w700)),
        ],
      );

  Widget _actions() {
    switch (_run.status) {
      case PayrollStatus.draft:
        return PermissionGate(
          module: 'hr',
          action: 'create',
          child: AppButton(
              label: 'Calculate',
              icon: Icons.calculate_outlined,
              fullWidth: true,
              loading: _busy,
              onPressed: _busy ? null : _calculate),
        );
      case PayrollStatus.calculated:
        return PermissionGate(
          module: 'hr',
          action: 'approve',
          child: AppButton(
              label: 'Approve',
              icon: Icons.verified_outlined,
              fullWidth: true,
              loading: _busy,
              onPressed: _busy ? null : _approve),
        );
      case PayrollStatus.approved:
        return PermissionGate(
          module: 'hr',
          action: 'approve',
          child: AppButton(
              label: 'Disburse',
              icon: Icons.account_balance_wallet_outlined,
              fullWidth: true,
              loading: _busy,
              onPressed: _busy ? null : _disburse),
        );
      case PayrollStatus.disbursed:
        final je = _run.journalEntryId;
        if (je == null) {
          return Text('Disbursed.',
              style: AppTypography.footnote
                  .copyWith(color: AppColors.success));
        }
        return AppButton(
          label: 'View journal',
          icon: Icons.receipt_long_outlined,
          variant: AppButtonVariant.tinted,
          fullWidth: true,
          onPressed: () => context.push('/accounting/journal/$je'),
        );
      case PayrollStatus.cancelled:
        return const SizedBox();
    }
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow(
      {required this.item, required this.run, required this.employer});
  final PayrollItem item;
  final PayrollRun run;
  final String employer;

  @override
  Widget build(BuildContext context) {
    final advance = item.deductions['advance'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.employeeName ?? item.employeeId,
                    style: AppTypography.subhead
                        .copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                    'basic ${formatPkr(item.basic)}'
                    '${item.overtimeAmount > 0 ? ' · OT ${formatPkr(item.overtimeAmount)}' : ''}'
                    '${advance > 0 ? ' · adv −${formatPkr(advance)}' : ''}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 2),
                Text('Net ${formatPkr(item.netSalary)}',
                    style: AppTypography.footnote
                        .copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined,
                color: AppColors.accent),
            tooltip: 'Payslip',
            onPressed: () => Printing.layoutPdf(
              onLayout: (_) => PayslipPdfService().generate(
                  item: item, run: run, employerName: employer),
            ),
          ),
        ],
      ),
    );
  }
}
