import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:printing/printing.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_confirm_dialog.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/design/widgets/app_money_text.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/payroll.dart';
import '../../domain/failures/hr_failure.dart';
import '../../data/services/payslip_pdf_service.dart';
import '../controllers/payroll_controller.dart';
import '../widgets/hr_ui.dart';

class PayrollRunDetailPage extends ConsumerWidget {
  const PayrollRunDetailPage({super.key, required this.runId});
  final String runId;

  static const _payAccount = '1000'; // Cash — mirrors H5 default

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(payrollRunDetailProvider(runId));
    final employer = ref.watch(currentBranchProvider)?.name ?? 'Payslip';

    return async.when(
      loading: () => const AppDetailScaffold(
        eyebrow: 'HR · Payroll',
        title: 'Payroll run',
        child: Padding(
          padding: EdgeInsets.only(top: 80),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, _) => AppDetailScaffold(
        eyebrow: 'HR · Payroll',
        title: 'Payroll run',
        child: AppErrorState(
          title: "We couldn't load the run",
          body:
              "We couldn't reach the server. Try again once you're back online.",
          onRetry: () => ref.invalidate(payrollRunDetailProvider(runId)),
        ),
      ),
      data: (detail) =>
          _Body(runId: runId, detail: detail, employer: employer),
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
    final ok = await showAppConfirm(
      context,
      title: 'Disburse payroll',
      message: 'Pay ${formatPkr(_run.totalNet)} net to account '
          '${PayrollRunDetailPage._payAccount} (Cash) and post the journal?',
      confirmLabel: 'Disburse',
    );
    if (!ok) return;
    await _run3(() => ref.read(payrollActionsProvider).disburse(
        widget.runId, PayrollRunDetailPage._payAccount));
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.detail.items;
    final range = '${_run.startDate.toIso8601String().substring(0, 10)} → '
        '${_run.endDate.toIso8601String().substring(0, 10)}';

    return AppDetailScaffold(
      eyebrow: 'HR · Payroll',
      title: _run.period,
      description: '$range · ${_run.employeeCount} employees',
      actions: [
        AppPill(
          label: payrollStatusLabels[_run.status]!,
          tone: payrollStatusTone(_run.status),
        ),
        if (items.isNotEmpty)
          AppButton(
            label: 'Print all',
            variant: AppButtonVariant.tinted,
            size: AppButtonSize.sm,
            icon: LucideIcons.printer,
            onPressed: () => Printing.layoutPdf(
              onLayout: (_) => PayslipPdfService().generateAll(
                  items: items, run: _run, employerName: widget.employer),
            ),
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Summary(run: _run),
          if (_error != null) ...[
            const SizedBox(height: 14),
            AppInlineBanner(message: _error!, type: BannerType.error),
          ],
          const SizedBox(height: 14),
          _actions(),
          const SizedBox(height: 16),
          if (items.isNotEmpty)
            _ItemsTable(items: items, run: _run, employer: widget.employer)
          else if (_run.status == PayrollStatus.draft)
            const _DraftPanel()
          else
            const AppEmptyState(
              icon: LucideIcons.wallet,
              title: 'No items',
              body: 'This run has no payslips.',
            ),
        ],
      ),
    );
  }

  Widget _actions() {
    switch (_run.status) {
      case PayrollStatus.draft:
        return PermissionGate(
          module: 'hr',
          action: 'create',
          child: AppButton(
              label: 'Calculate',
              icon: LucideIcons.calculator,
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
              icon: LucideIcons.checkCircle2,
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
              icon: LucideIcons.wallet,
              fullWidth: true,
              loading: _busy,
              onPressed: _busy ? null : _disburse),
        );
      case PayrollStatus.disbursed:
        final je = _run.journalEntryId;
        if (je == null) {
          return AppButton(
            label: 'Disbursed',
            variant: AppButtonVariant.tinted,
            icon: LucideIcons.checkCircle2,
            fullWidth: true,
            onPressed: null,
          );
        }
        return AppButton(
          label: 'View journal',
          icon: LucideIcons.receiptText,
          variant: AppButtonVariant.tinted,
          fullWidth: true,
          onPressed: () => context.push('/accounting/journal/$je'),
        );
      case PayrollStatus.cancelled:
        return const SizedBox();
    }
  }
}

/// Gross / Deductions / Net summary. Collapses to a column at narrow widths so
/// no tile is ever dropped from a shared row.
class _Summary extends StatelessWidget {
  const _Summary({required this.run});
  final PayrollRun run;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final tiles = <Widget>[
      _SummaryTile(label: 'Gross', value: run.totalGross),
      _SummaryTile(
          label: 'Deductions', value: run.totalDeductions, color: lum.dangerText),
      _SummaryTile(
          label: 'Net payable',
          value: run.totalNet,
          color: lum.accent,
          raised: true),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 460) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                tiles[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(child: tiles[i]),
            ],
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    this.color,
    this.raised = false,
  });

  final String label;
  final double value;
  final Color? color;
  final bool raised;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: raised ? ClayVariant.raised : ClayVariant.soft,
      color: raised ? null : lum.surface,
      gradient: raised
          ? LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [lum.surface, lum.surface2],
            )
          : null,
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600, color: lum.g500)),
          const SizedBox(height: 8),
          AppMoneyText(value, size: 19, color: color),
        ],
      ),
    );
  }
}

/// Per-employee payslip table: a header strip over hairline-separated rows.
class _ItemsTable extends StatelessWidget {
  const _ItemsTable(
      {required this.items, required this.run, required this.employer});
  final List<PayrollItem> items;
  final PayrollRun run;
  final String employer;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Column(
          children: [
            _headerRow(lum),
            for (final it in items)
              _ItemRow(item: it, run: run, employer: employer),
          ],
        ),
      ),
    );
  }

  Widget _headerRow(LumColors lum) {
    Widget cell(String t, {bool right = false}) => Text(t,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: AppTypography.caption.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: lum.g500,
        ));
    return Container(
      color: lum.surface2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 14, child: cell('EMPLOYEE')),
          Expanded(flex: 8, child: cell('BASIC', right: true)),
          Expanded(flex: 8, child: cell('OT', right: true)),
          Expanded(flex: 8, child: cell('ADVANCE', right: true)),
          Expanded(flex: 9, child: cell('NET', right: true)),
          const SizedBox(width: 40),
        ],
      ),
    );
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
    final lum = context.lum;
    final basic = item.basic;
    final overtimeAmount = item.overtimeAmount;
    final advance = item.deductions['advance'] ?? 0;
    final netSalary = item.netSalary;

    Widget num(double v, {Color? color, FontWeight? weight}) => Text(
          formatAmount(v, decimals: 0),
          textAlign: TextAlign.right,
          style: AppTypography.monoValue.copyWith(
            fontSize: 12.5,
            fontWeight: weight,
            color: color ?? lum.textPrimary,
          ),
        );

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: lum.hairline)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            flex: 14,
            child: Text(item.employeeName ?? item.employeeId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.subhead.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: lum.textPrimary)),
          ),
          Expanded(flex: 8, child: num(basic)),
          Expanded(flex: 8, child: num(overtimeAmount, color: lum.successText)),
          Expanded(flex: 8, child: num(advance, color: lum.dangerText)),
          Expanded(
              flex: 9, child: num(netSalary, weight: FontWeight.w700)),
          SizedBox(
            width: 40,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Icon(LucideIcons.printer, size: 16, color: lum.g500),
              tooltip: 'Payslip',
              onPressed: () => Printing.layoutPdf(
                onLayout: (_) => PayslipPdfService().generate(
                    item: item, run: run, employerName: employer),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draft state: a dashed panel inviting the user to calculate payslips.
class _DraftPanel extends StatelessWidget {
  const _DraftPanel();

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return CustomPaint(
      painter: _DashedBorderPainter(color: lum.hairline2, radius: AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          children: [
            Icon(LucideIcons.calculator, size: 30, color: lum.g400),
            const SizedBox(height: 12),
            Text('Nothing calculated yet',
                textAlign: TextAlign.center,
                style: AppTypography.title2
                    .copyWith(fontSize: 17, color: lum.g700)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                'Run Calculate to build payslips for this period.',
                textAlign: TextAlign.center,
                style:
                    AppTypography.body.copyWith(height: 1.5, color: lum.g500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final dashed = Path();
    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        dashed.addPath(metric.extractPath(d, d + dash), Offset.zero);
        d += dash + gap;
      }
    }
    canvas.drawPath(
      dashed,
      Paint()
        ..color = color
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
