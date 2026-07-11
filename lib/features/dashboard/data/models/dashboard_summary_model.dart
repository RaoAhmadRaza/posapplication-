import '../../domain/entities/dashboard_summary.dart';

class DashboardSummaryModel {
  static DashboardSummary fromJson(Map<String, dynamic> json) {
    final recentSales = (json['recent_sales'] as List<dynamic>?)
            ?.map((r) {
              final m = r as Map<String, dynamic>;
              return RecentSale(
                invoiceNumber: m['invoice_number'] as String,
                grandTotal: double.tryParse(m['grand_total'].toString()) ?? 0,
                status: m['status'] as String,
                createdAt: DateTime.parse(m['created_at'] as String),
                customer: m['customer'] as String?,
              );
            })
            .toList() ??
        <RecentSale>[];

    final salesTrend = (json['sales_trend'] as List<dynamic>?)
            ?.map((t) {
              final m = t as Map<String, dynamic>;
              return TrendPoint(
                day: DateTime.parse(m['day'] as String),
                total: double.tryParse(m['total'].toString()) ?? 0,
              );
            })
            .toList() ??
        <TrendPoint>[];

    final breakdown = <String, double>{};
    final pb = json['payment_breakdown'];
    if (pb is Map) {
      for (final e in pb.entries) {
        breakdown[e.key.toString()] = double.tryParse(e.value.toString()) ?? 0;
      }
    }

    return DashboardSummary(
      todaySales: double.tryParse(json['today_sales'].toString()) ?? 0,
      todayTxns: json['today_txns'] as int? ?? 0,
      todayProfit: double.tryParse(json['today_profit'].toString()) ?? 0,
      receivables: double.tryParse(json['receivables'].toString()) ?? 0,
      stockValue: double.tryParse(json['stock_value'].toString()) ?? 0,
      lowStockCount: json['low_stock_count'] as int? ?? 0,
      recentSales: recentSales,
      salesTrend: salesTrend,
      paymentBreakdown: breakdown,
    );
  }
}
