import '../../domain/entities/reporting.dart';

double _num(dynamic v) => double.tryParse(v.toString()) ?? 0;
int _int(dynamic v) => (v is int) ? v : int.tryParse(v.toString()) ?? 0;
DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

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
}
