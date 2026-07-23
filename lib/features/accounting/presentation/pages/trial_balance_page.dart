import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_toast.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../controllers/reports_controller.dart';
import '../widgets/acct_report_table.dart';
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

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'Trial balance',
      actions: [
        PermissionGate(
          module: 'accounting',
          action: 'export',
          child: AppButton(
            label: 'Export',
            variant: AppButtonVariant.tinted,
            size: AppButtonSize.sm,
            icon: LucideIcons.download,
            onPressed: () =>
                showAppToast(context, 'Export coming soon'),
          ),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              ReportDateChip(
                  label: 'As of',
                  value: _asOf,
                  onPick: (d) => setState(() => _asOf = d)),
              ReportBranchDropdown(
                  value: _branchId,
                  onChanged: (v) => setState(() => _branchId = v)),
            ],
          ),
          const SizedBox(height: 14),
          report.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 50),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.only(top: 30),
              child: AppErrorState(
                title: 'Couldn\'t load report',
                body: 'Your data is safe. Check the connection and try again.',
                onRetry: () => ref.invalidate(
                    trialBalanceProvider((asOf: _asOf, branchId: _branchId))),
              ),
            ),
            data: (tb) => AcctReportTable(
              rows: [
                for (final r in tb.rows)
                  AcctReportRow(
                    code: r.code,
                    name: r.name,
                    debit: r.debit,
                    credit: r.credit,
                  ),
              ],
              totalDebit: tb.totalDebit,
              totalCredit: tb.totalCredit,
              badge: AppPill(
                label: tb.balanced ? 'Balanced' : 'Unbalanced',
                tone: tb.balanced ? AppPillTone.success : AppPillTone.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
