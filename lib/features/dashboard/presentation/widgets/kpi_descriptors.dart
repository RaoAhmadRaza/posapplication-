import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/drilldown.dart';

/// Drilldown navigation payload passed to the /dashboard/drilldown route as
/// `extra`. The record shape is the contract with the router's cast — do not
/// change it without updating router.dart.
typedef DrilldownNav = ({DrilldownArgs args, String title});

/// Which token an icon paints itself with. Resolved against `context.lum` at
/// build time so tiles stay theme-aware.
enum KpiAccent { neutral, success, warning }

/// One KPI descriptor: presentation (label/icon/accent/sub-label) plus the
/// value extractor and the tap target.
class KpiDesc {
  const KpiDesc(
    this.label,
    this.icon,
    this.accent,
    this.value, {
    required this.subLabel,
    this.isCount = false,
    this.drill,
    this.route,
  });

  final String label;
  final IconData icon;
  final KpiAccent accent;
  final bool isCount;
  final double Function(DashboardSummary) value;

  /// Static description of what the figure is. The design shows a trend delta
  /// here, but DashboardSummary carries no comparison fields — rather than
  /// inventing one, every KPI except today_sales states its own meaning.
  /// See `todaySalesDelta` for the one genuinely derivable trend.
  final String subLabel;

  final DrilldownNav? Function(String? branchId, String date)? drill;

  /// Direct deep-link route for KPIs backed by an existing page.
  final String? route;

  Color iconColor(LumColors lum) => switch (accent) {
        KpiAccent.neutral => lum.g500,
        KpiAccent.success => lum.success,
        KpiAccent.warning => lum.warning,
      };
}

/// A real day-over-day change for today's sales, derived from the trend series
/// that the summary already carries. Null when there is nothing to compare
/// against, or when yesterday was zero (a percentage would be meaningless).
({double pct, bool up})? todaySalesDelta(DashboardSummary s) {
  if (s.salesTrend.length < 2) return null;
  final today = s.salesTrend.last.total;
  final yesterday = s.salesTrend[s.salesTrend.length - 2].total;
  if (yesterday == 0) return null;
  final change = (today - yesterday) / yesterday * 100;
  return (pct: change.abs(), up: change >= 0);
}

/// The 10 KPIs, keyed to `kpiKeysDefault`. Keys, value extractors, drilldowns
/// and routes are unchanged from the pre-reskin descriptors.
final kpiDescriptors = <String, KpiDesc>{
  'today_sales': KpiDesc(
    "Today's sales",
    LucideIcons.trendingUp,
    KpiAccent.success,
    (s) => s.todaySales,
    subLabel: 'today',
    drill: (b, d) => (
      args: DrilldownArgs(DrilldownType.sales, branchId: b, date: d),
      title: "Today's Sales",
    ),
  ),
  'today_txns': KpiDesc(
    'Transactions',
    LucideIcons.receipt,
    KpiAccent.neutral,
    (s) => s.todayTxns.toDouble(),
    subLabel: 'today',
    isCount: true,
    drill: (b, d) => (
      args: DrilldownArgs(DrilldownType.sales, branchId: b, date: d),
      title: 'Transactions',
    ),
  ),
  'today_profit': KpiDesc(
    "Today's profit",
    LucideIcons.coins,
    KpiAccent.success,
    (s) => s.todayProfit,
    subLabel: 'today',
    drill: (b, d) => (
      args: DrilldownArgs(DrilldownType.sales, branchId: b, date: d),
      title: "Today's Profit",
    ),
  ),
  'receivables': KpiDesc(
    'Receivables',
    LucideIcons.fileText,
    KpiAccent.neutral,
    (s) => s.receivables,
    subLabel: 'outstanding',
    drill: (b, d) => (
      args: DrilldownArgs(DrilldownType.receivables, branchId: b),
      title: 'Receivables',
    ),
  ),
  'stock_value': KpiDesc(
    'Stock value',
    LucideIcons.warehouse,
    KpiAccent.neutral,
    (s) => s.stockValue,
    subLabel: 'at cost',
    // Reports is now its own shell branch — deep-link to the hub (its own
    // Navigator has no route beneath a go'd sub-page, so back would be dead).
    route: '/reports',
  ),
  'low_stock': KpiDesc(
    'Low stock',
    LucideIcons.package,
    KpiAccent.warning,
    (s) => s.lowStockCount.toDouble(),
    subLabel: 'below reorder point',
    isCount: true,
    drill: (b, d) => (
      args: DrilldownArgs(DrilldownType.lowStock, branchId: b),
      title: 'Low Stock',
    ),
  ),
  'payables': KpiDesc(
    'Payables',
    LucideIcons.fileMinus,
    KpiAccent.neutral,
    (s) => s.payablesTotal,
    subLabel: 'due',
    drill: (b, d) => (
      args: DrilldownArgs(DrilldownType.payables),
      title: 'Payables',
    ),
  ),
  'cash': KpiDesc(
    'Cash',
    LucideIcons.banknote,
    KpiAccent.neutral,
    (s) => s.cashBalance,
    subLabel: 'on hand',
    drill: (b, d) => (
      args: DrilldownArgs(DrilldownType.account, entityId: '1000'),
      title: 'Cash Ledger',
    ),
  ),
  'bank': KpiDesc(
    'Bank',
    LucideIcons.landmark,
    KpiAccent.neutral,
    (s) => s.bankBalance,
    subLabel: 'cleared balance',
    drill: (b, d) => (
      args: DrilldownArgs(DrilldownType.account, entityId: '1010'),
      title: 'Bank Ledger',
    ),
  ),
  'pl': KpiDesc(
    'P&L',
    LucideIcons.barChart3,
    KpiAccent.success,
    (s) => s.plSnapshot,
    subLabel: 'this month',
    route: '/accounting/reports/profit-loss',
  ),
};
