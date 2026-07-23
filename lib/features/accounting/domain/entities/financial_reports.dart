import 'report_line.dart';

/// Read-only financial statements assembled from the trial_balance,
/// profit_loss and balance_sheet RPCs.
class TrialBalanceRow {
  final String code;
  final String name;
  final double debit;
  final double credit;

  const TrialBalanceRow({
    required this.code,
    required this.name,
    required this.debit,
    required this.credit,
  });
}

class TrialBalance {
  final bool balanced;
  final double totalDebit;
  final double totalCredit;
  final List<TrialBalanceRow> rows;

  const TrialBalance({
    required this.balanced,
    required this.totalDebit,
    required this.totalCredit,
    required this.rows,
  });
}

class ProfitLoss {
  final String from;
  final String to;
  final double revenue;
  final double expenses;
  final double netProfit;

  /// Per-account breakdown (type REVENUE or EXPENSE). Empty when the backend
  /// predates the by_account key — the totals above still render.
  final List<ReportLine> lines;

  const ProfitLoss({
    required this.from,
    required this.to,
    required this.revenue,
    required this.expenses,
    required this.netProfit,
    this.lines = const [],
  });

  List<ReportLine> get revenueLines =>
      lines.where((l) => l.type == 'REVENUE').toList();
  List<ReportLine> get expenseLines =>
      lines.where((l) => l.type == 'EXPENSE').toList();
}

class BalanceSheet {
  final double assets;
  final double liabilities;
  final double equity;
  final double retainedEarnings;
  final bool balanced;

  /// Per-account breakdown (type ASSET, LIABILITY or EQUITY). Empty when the
  /// backend predates the by_account key — the totals above still render.
  final List<ReportLine> lines;

  const BalanceSheet({
    required this.assets,
    required this.liabilities,
    required this.equity,
    required this.retainedEarnings,
    required this.balanced,
    this.lines = const [],
  });

  List<ReportLine> get assetLines =>
      lines.where((l) => l.type == 'ASSET').toList();
  List<ReportLine> get liabilityLines =>
      lines.where((l) => l.type == 'LIABILITY').toList();
  List<ReportLine> get equityLines =>
      lines.where((l) => l.type == 'EQUITY').toList();
}
