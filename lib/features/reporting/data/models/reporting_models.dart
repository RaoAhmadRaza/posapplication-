import '../../domain/entities/ai_recommendation.dart';
import '../../domain/entities/report_schedule.dart';
import '../../domain/entities/reporting.dart';

double _num(dynamic v) => double.tryParse(v.toString()) ?? 0;
int _int(dynamic v) => (v is int) ? v : int.tryParse(v.toString()) ?? 0;
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

List<String> _strList(dynamic v) =>
    (v is List) ? v.map((e) => e.toString()).toList() : <String>[];
Map<String, dynamic> _map(dynamic v) =>
    (v is Map) ? Map<String, dynamic>.from(v) : <String, dynamic>{};

class ReportingModels {
  static InventoryValuationRow inventory(Map<String, dynamic> j) =>
      InventoryValuationRow(
        productId: j['product_id'].toString(),
        productName: (j['product_name'] ?? '—').toString(),
        sku: j['sku'] as String?,
        categoryName: j['category_name'] as String?,
        qtyOnHand: _num(j['qty_on_hand']),
        avgCost: _num(j['avg_cost']),
        totalValue: _num(j['total_value']),
        sellingPrice: _num(j['selling_price']),
        retailValue: _num(j['retail_value']),
        reorderPoint: _num(j['reorder_point']),
        belowReorder: j['below_reorder'] == true,
      );

  static ProductPerformanceRow product(Map<String, dynamic> j) =>
      ProductPerformanceRow(
        productId: j['product_id'].toString(),
        productName: (j['product_name'] ?? '—').toString(),
        sku: j['sku'] as String?,
        unitsSold: _num(j['units_sold']),
        revenue: _num(j['revenue']),
        profit: _num(j['profit']),
        invoiceCount: _int(j['invoice_count']),
        lastSoldAt: _date(j['last_sold_at']),
      );

  static AgingRow aging(Map<String, dynamic> j, {required bool customer}) =>
      AgingRow(
        id: (customer ? j['customer_id'] : j['supplier_id']).toString(),
        name: (customer ? j['customer_name'] : j['supplier_name'] ?? '—')
            .toString(),
        totalBalance: _num(j['total_balance']),
        current: _num(j['bucket_current']),
        b1to30: _num(j['bucket_1_30']),
        b31to60: _num(j['bucket_31_60']),
        b61to90: _num(j['bucket_61_90']),
        b90plus: _num(j['bucket_90_plus']),
        maxDaysOverdue: _int(j['max_days_overdue']),
      );

  static DailySalesRow daily(Map<String, dynamic> j) => DailySalesRow(
        saleDate: _date(j['sale_date']) ?? DateTime(2020),
        totalRevenue: _num(j['total_revenue']),
        totalProfit: _num(j['total_profit']),
        invoiceCount: _int(j['invoice_count']),
      );

  static ReportSchedule schedule(Map<String, dynamic> j) => ReportSchedule(
        id: j['id'].toString(),
        reportType: (j['report_type'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        frequency: (j['frequency'] ?? 'DAILY').toString(),
        recipients: _strList(j['recipients_json']),
        outputFormat: (j['output_format'] ?? 'PDF').toString(),
        filters: _map(j['filters_json']),
        isActive: j['is_active'] == true,
        nextRunAt: _date(j['next_run_at']),
        lastRunAt: _date(j['last_run_at']),
      );

  static AiRecommendation recommendation(Map<String, dynamic> j) =>
      AiRecommendation(
        id: j['id'].toString(),
        recommendationType: (j['recommendation_type'] ?? '').toString(),
        entityType: (j['entity_type'] ?? '').toString(),
        entityId: j['entity_id'].toString(),
        recommendation: _map(j['recommendation_json']),
        confidenceScore: _num(j['confidence_score']),
        reasoning: j['reasoning'] as String?,
        status: (j['status'] ?? 'PENDING').toString(),
      );
}
