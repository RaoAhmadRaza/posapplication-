import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../controllers/reports_controller.dart';
import '../widgets/acct_statement.dart';
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

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: 'Balance sheet',
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
                    balanceSheetProvider((asOf: _asOf, branchId: _branchId))),
              ),
            ),
            data: (bs) {
              final claims = bs.liabilities + bs.equity + bs.retainedEarnings;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AppPill(
                      label: bs.balanced ? 'Balanced' : 'Unbalanced',
                      tone:
                          bs.balanced ? AppPillTone.success : AppPillTone.danger,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AcctStatementSection(
                          heading: 'Assets',
                          lines: [
                            for (final l in bs.assetLines)
                              (name: l.name, amount: l.amount),
                          ],
                          subtotalLabel: 'Total assets',
                          subtotalAmount: bs.assets,
                        ),
                        AcctStatementSection(
                          heading: 'Liabilities',
                          topGap: true,
                          lines: [
                            for (final l in bs.liabilityLines)
                              (name: l.name, amount: l.amount),
                          ],
                          subtotalLabel: 'Total liabilities',
                          subtotalAmount: bs.liabilities,
                        ),
                        AcctStatementSection(
                          heading: 'Equity',
                          topGap: true,
                          lines: [
                            for (final l in bs.equityLines)
                              (name: l.name, amount: l.amount),
                            (name: 'Net profit (period)',
                              amount: bs.retainedEarnings),
                          ],
                        ),
                        AcctNetRow(
                            label: 'Liabilities + equity', amount: claims),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
