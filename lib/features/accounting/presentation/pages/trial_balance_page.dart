import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
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
                title: 'Unable to load report',
                body: 'Check your connection and try again.',
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
