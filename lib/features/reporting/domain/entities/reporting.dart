/// Row of mv_inventory_valuation (canonical stock).
class InventoryValuationRow {
  final String productId;
  final String productName;
  final String? sku;
  final String? categoryName;
  final double qtyOnHand;
  final double avgCost;
  final double totalValue;
  final double sellingPrice;
  final double retailValue;
  final double reorderPoint;
  final bool belowReorder;

  const InventoryValuationRow({
    required this.productId,
    required this.productName,
    this.sku,
    this.categoryName,
    required this.qtyOnHand,
    required this.avgCost,
    required this.totalValue,
    required this.sellingPrice,
    required this.retailValue,
    required this.reorderPoint,
    required this.belowReorder,
  });
}

/// Row of mv_product_performance.
class ProductPerformanceRow {
  final String productId;
  final String productName;
  final String? sku;
  final double unitsSold;
  final double revenue;
  final double profit;
  final int invoiceCount;
  final DateTime? lastSoldAt;

  const ProductPerformanceRow({
    required this.productId,
    required this.productName,
    this.sku,
    required this.unitsSold,
    required this.revenue,
    required this.profit,
    required this.invoiceCount,
    this.lastSoldAt,
  });
}

/// Row of mv_customer_aging / mv_supplier_aging (shared shape).
class AgingRow {
  final String id;
  final String name;
  final double totalBalance;
  final double current;
  final double b1to30;
  final double b31to60;
  final double b61to90;
  final double b90plus;
  final int maxDaysOverdue;

  const AgingRow({
    required this.id,
    required this.name,
    required this.totalBalance,
    required this.current,
    required this.b1to30,
    required this.b31to60,
    required this.b61to90,
    required this.b90plus,
    required this.maxDaysOverdue,
  });
}

/// Row of mv_daily_sales_summary.
class DailySalesRow {
  final DateTime saleDate;
  final double totalRevenue;
  final double totalProfit;
  final int invoiceCount;

  const DailySalesRow({
    required this.saleDate,
    required this.totalRevenue,
    required this.totalProfit,
    required this.invoiceCount,
  });
}
