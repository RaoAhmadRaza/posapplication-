import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../controllers/reports_controller.dart';
import '../widgets/acct_statement.dart';
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

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'Profit & loss',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              ReportDateChip(
                  label: 'From',
                  value: _from,
                  onPick: (d) => setState(() => _from = d)),
              ReportDateChip(
                  label: 'To',
                  value: _to,
                  onPick: (d) => setState(() => _to = d)),
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
                onRetry: () => ref.invalidate(profitLossProvider(
                    (from: _from, to: _to, branchId: _branchId))),
              ),
            ),
            data: (pl) => AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AcctStatementSection(
                    heading: 'Revenue',
                    lines: [
                      for (final l in pl.revenueLines)
                        (name: l.name, amount: l.amount),
                    ],
                    subtotalLabel: 'Total revenue',
                    subtotalAmount: pl.revenue,
                  ),
                  AcctStatementSection(
                    heading: 'Expenses',
                    topGap: true,
                    lines: [
                      for (final l in pl.expenseLines)
                        (name: l.name, amount: l.amount),
                    ],
                    subtotalLabel: 'Total expenses',
                    subtotalAmount: pl.expenses,
                  ),
                  AcctNetRow(label: 'Net profit', amount: pl.netProfit),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
