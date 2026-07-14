class RecentSale {
  final String invoiceNumber;
  final double grandTotal;
  final String status;
  final DateTime createdAt;
  final String? customer;

  const RecentSale({
    required this.invoiceNumber,
    required this.grandTotal,
    required this.status,
    required this.createdAt,
    this.customer,
  });
}

class TrendPoint {
  final DateTime day;
  final double total;

  const TrendPoint({required this.day, required this.total});
}

class DashboardSummary {
  final double todaySales;
  final int todayTxns;
  final double todayProfit;
  final double receivables;
  final double stockValue;
  final int lowStockCount;
  final List<RecentSale> recentSales;
  final List<TrendPoint> salesTrend;
  final Map<String, double> paymentBreakdown;
  final double payablesTotal;
  final double cashBalance;
  final double bankBalance;
  final double plSnapshot;

  const DashboardSummary({
    required this.todaySales,
    required this.todayTxns,
    required this.todayProfit,
    required this.receivables,
    required this.stockValue,
    required this.lowStockCount,
    required this.recentSales,
    required this.salesTrend,
    required this.paymentBreakdown,
    required this.payablesTotal,
    required this.cashBalance,
    required this.bankBalance,
    required this.plSnapshot,
  });
}
