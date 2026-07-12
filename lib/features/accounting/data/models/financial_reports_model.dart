import '../../domain/entities/financial_reports.dart';

double _d(Object? v) => double.tryParse(v.toString()) ?? 0;

class FinancialReportsModel {
  static TrialBalance trialBalance(Map<String, dynamic> j) {
    final rawRows = (j['rows'] as List<dynamic>? ?? const []);
    return TrialBalance(
      balanced: j['balanced'] == true,
      totalDebit: _d(j['total_debit']),
      totalCredit: _d(j['total_credit']),
      rows: rawRows
          .whereType<Map<String, dynamic>>()
          .map((r) => TrialBalanceRow(
                code: r['code']?.toString() ?? '',
                name: r['name']?.toString() ?? '',
                debit: _d(r['debit']),
                credit: _d(r['credit']),
              ))
          .toList(),
    );
  }

  static ProfitLoss profitLoss(Map<String, dynamic> j) {
    return ProfitLoss(
      from: j['from']?.toString() ?? '',
      to: j['to']?.toString() ?? '',
      revenue: _d(j['revenue']),
      expenses: _d(j['expenses']),
      netProfit: _d(j['net_profit']),
    );
  }

  static BalanceSheet balanceSheet(Map<String, dynamic> j) {
    return BalanceSheet(
      assets: _d(j['assets']),
      liabilities: _d(j['liabilities']),
      equity: _d(j['equity_total'] ?? j['equity']),
      retainedEarnings: _d(j['retained_earnings']),
      balanced: j['balanced'] == true,
    );
  }
}
