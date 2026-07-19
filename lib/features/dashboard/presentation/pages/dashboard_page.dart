import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/format.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/supabase.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../../auth/presentation/controllers/permission_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../controllers/kpi_layout_controller.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/drilldown.dart';
import '../../../auth/presentation/controllers/profile_controller.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';

/// Whether the KPI grid is in "edit layout" mode (per-session UI toggle).
final dashboardEditingProvider =
    NotifierProvider<DashboardEditing, bool>(DashboardEditing.new);

class DashboardEditing extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PermissionGate(
      module: 'reports',
      action: 'read',
      fallback: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48, color: AppColors.textHint),
                const SizedBox(height: 16),
                Text('No access to reports.', style: AppTypography.subhead.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
      child: _buildContent(context, ref),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref) {
    final user = supabase.auth.currentUser;
    final state = ref.watch(dashboardProvider);

    if (state.isLoading) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        children: const [
          SizedBox(height: AppSpacing.xs),
          SizedBox(height: AppSpacing.xxl),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (state.hasError) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
        children: [
          const SizedBox(height: AppSpacing.xs),
          const SizedBox(height: AppSpacing.xxl),
          AppInlineBanner(message: 'Could not load dashboard.', type: BannerType.error),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Retry',
            onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
            variant: AppButtonVariant.plain,
          ),
        ],
      );
    }

    final summary = state.value!;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        title: Text('Dashboard', style: AppTypography.largeTitle),
        actions: [
          const NotificationBell(),
          Consumer(
            builder: (context, ref, _) {
              final editing = ref.watch(dashboardEditingProvider);
              return IconButton(
                icon: Icon(
                  editing ? Icons.check : Icons.tune,
                  color: AppColors.accent,
                  size: 22,
                ),
                onPressed: () =>
                    ref.read(dashboardEditingProvider.notifier).toggle(),
                tooltip: editing ? 'Done' : 'Edit layout',
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.accent, size: 22),
            onPressed: () => ref.read(dashboardProvider.notifier).refresh(),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
          children: [
            const SizedBox(height: AppSpacing.xs),
            _WelcomeCard(user: user),
            const SizedBox(height: AppSpacing.xl),
            _KpiGrid(summary: summary),
            const SizedBox(height: AppSpacing.xxl),
            if (summary.salesTrend.isNotEmpty) ...[
              _SalesTrendChart(points: summary.salesTrend),
              const SizedBox(height: AppSpacing.xxl),
            ],
            if (summary.paymentBreakdown.isNotEmpty) ...[
              _PaymentPieChart(breakdown: summary.paymentBreakdown),
              const SizedBox(height: AppSpacing.xxl),
            ],
            if (summary.recentSales.isNotEmpty) ...[
              Text('Recent Sales', style: AppTypography.title2),
              const SizedBox(height: AppSpacing.md),
              ...summary.recentSales.map((s) => _RecentSaleRow(sale: s)),
            ],
            const SizedBox(height: AppSpacing.xxl),
            _QuickLaunch(),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }
}

class _SalesTrendChart extends StatelessWidget {
  const _SalesTrendChart({required this.points});
  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final maxY = points.isEmpty
        ? 100.0
        : points.map((p) => p.total).reduce((a, b) => a > b ? a : b) * 1.2;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sales Trend (7 days)', style: AppTypography.headline),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY > 0 ? maxY : 100,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, _) {
                      return BarTooltipItem(
                        formatPkr(rod.toY),
                        const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (val, _) {
                        final idx = val.toInt();
                        if (idx < 0 || idx >= points.length) return const SizedBox();
                        final day = points[idx].day;
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${day.day}/${day.month}',
                            style: AppTypography.caption.copyWith(color: AppColors.textHint),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (val, _) {
                        return Text(
                          val.toStringAsFixed(0),
                          style: AppTypography.caption.copyWith(color: AppColors.textHint),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? (maxY / 4).ceilToDouble() : 25,
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(points.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: points[i].total,
                        color: AppColors.accent,
                        width: 18,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentPieChart extends StatelessWidget {
  const _PaymentPieChart({required this.breakdown});
  final Map<String, double> breakdown;

  static const _methodColors = [
    AppColors.accent,
    AppColors.success,
    AppColors.warning,
    AppColors.destructive,
    Color(0xFF5856D6),
    Color(0xFFFF2D55),
    Color(0xFFAF52DE),
  ];

  @override
  Widget build(BuildContext context) {
    final total = breakdown.values.fold(0.0, (a, b) => a + b);
    final entries = breakdown.entries.toList();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Methods', style: AppTypography.headline),
          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (_, _) {},
                      ),
                      sections: List.generate(entries.length, (i) {
                        final pct = total > 0 ? entries[i].value / total * 100 : 0.0;
                        return PieChartSectionData(
                          value: entries[i].value,
                          title: '${pct.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          color: _methodColors[i % _methodColors.length],
                          radius: 60,
                        );
                      }),
                      centerSpaceRadius: 0,
                      sectionsSpace: 2,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.base),
                Expanded(
                  flex: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(entries.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _methodColors[i % _methodColors.length],
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                entries[i].key,
                                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final profileState = ref.watch(profileControllerProvider);
        final profile = profileState.value;
        final name = profile?.fullName ?? user?.email ?? '';
        return Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: AppTypography.headline.copyWith(color: AppColors.accent),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome, $name', style: AppTypography.headline),
                  if (profile?.roleName != null)
                    Text(
                      '${profile!.roleName} · ${profile.tenantName ?? ''}',
                      style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Drilldown navigation payload passed to the /dashboard/drilldown route as `extra`.
typedef DrilldownNav = ({DrilldownArgs args, String title});

/// One KPI descriptor: label/icon/color + value extractor + optional drilldown builder.
class _KpiDesc {
  final String label;
  final IconData icon;
  final Color color;
  final bool isCount;
  final double Function(DashboardSummary) value;
  final DrilldownNav? Function(String? branchId, String date)? drill;

  /// Direct deep-link route for KPIs backed by an existing page (not a drilldown list).
  final String? route;
  _KpiDesc(this.label, this.icon, this.color, this.value,
      {this.isCount = false, this.drill, this.route});
}

final _kpiDescriptors = <String, _KpiDesc>{
  'today_sales': _KpiDesc("Today's Sales", Icons.shopping_cart, AppColors.accent,
      (s) => s.todaySales,
      drill: (b, d) => (
            args: DrilldownArgs(DrilldownType.sales, branchId: b, date: d),
            title: "Today's Sales"
          )),
  'today_txns': _KpiDesc('Transactions', Icons.receipt_long, AppColors.success,
      (s) => s.todayTxns.toDouble(),
      isCount: true,
      drill: (b, d) => (
            args: DrilldownArgs(DrilldownType.sales, branchId: b, date: d),
            title: 'Transactions'
          )),
  'today_profit': _KpiDesc(
      "Today's Profit", Icons.trending_up, AppColors.success, (s) => s.todayProfit,
      drill: (b, d) => (
            args: DrilldownArgs(DrilldownType.sales, branchId: b, date: d),
            title: "Today's Profit"
          )),
  'receivables': _KpiDesc('Receivables', Icons.account_balance_wallet,
      AppColors.warning, (s) => s.receivables,
      drill: (b, d) => (
            args: DrilldownArgs(DrilldownType.receivables, branchId: b),
            title: 'Receivables'
          )),
  'stock_value': _KpiDesc(
      'Stock Value', Icons.inventory_2, AppColors.accent, (s) => s.stockValue,
      route: '/reports/inventory'),
  'low_stock': _KpiDesc('Low Stock', Icons.warning_amber, AppColors.destructive,
      (s) => s.lowStockCount.toDouble(),
      isCount: true,
      drill: (b, d) => (
            args: DrilldownArgs(DrilldownType.lowStock, branchId: b),
            title: 'Low Stock'
          )),
  'payables': _KpiDesc('Payables', Icons.payments, AppColors.destructive,
      (s) => s.payablesTotal,
      drill: (b, d) => (
            args: DrilldownArgs(DrilldownType.payables),
            title: 'Payables'
          )),
  'cash': _KpiDesc('Cash', Icons.savings, AppColors.success, (s) => s.cashBalance,
      drill: (b, d) => (
            args: DrilldownArgs(DrilldownType.account, entityId: '1000'),
            title: 'Cash Ledger'
          )),
  'bank': _KpiDesc(
      'Bank', Icons.account_balance, AppColors.accent, (s) => s.bankBalance,
      drill: (b, d) => (
            args: DrilldownArgs(DrilldownType.account, entityId: '1010'),
            title: 'Bank Ledger'
          )),
  'pl': _KpiDesc('P&L', Icons.show_chart, AppColors.success, (s) => s.plSnapshot,
      route: '/accounting/reports/profit-loss'),
};

class _KpiGrid extends ConsumerWidget {
  const _KpiGrid({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(kpiLayoutProvider).value ??
        kpiKeysDefault.map((k) => KpiPref(k, true)).toList();
    final editing = ref.watch(dashboardEditingProvider);
    return editing ? _buildEditList(ref, prefs) : _buildGrid(context, ref, prefs);
  }

  Widget _buildGrid(BuildContext context, WidgetRef ref, List<KpiPref> prefs) {
    final branchId = ref.read(currentBranchProvider)?.id;
    final date = DateTime.now().toIso8601String().substring(0, 10);
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final p in prefs)
          if (p.visible && _kpiDescriptors[p.key] != null)
            _tappableCard(context, _kpiDescriptors[p.key]!, branchId, date),
      ],
    );
  }

  Widget _tappableCard(
      BuildContext context, _KpiDesc d, String? branchId, String date) {
    final card = _KpiCard(
      label: d.label,
      value: d.value(summary),
      icon: d.icon,
      color: d.color,
      isCount: d.isCount,
    );
    final nav = d.drill?.call(branchId, date);
    final VoidCallback? onTap = nav != null
        ? () => context.push('/dashboard/drilldown', extra: nav)
        : (d.route != null ? () => context.push(d.route!) : null);
    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: card,
    );
  }

  Widget _buildEditList(WidgetRef ref, List<KpiPref> prefs) {
    final ctrl = ref.read(kpiLayoutProvider.notifier);
    return Column(
      children: [
        for (int i = 0; i < prefs.length; i++)
          _EditRow(
            label: _kpiDescriptors[prefs[i].key]?.label ?? prefs[i].key,
            visible: prefs[i].visible,
            onToggle: () => ctrl.toggle(prefs[i].key),
            onUp: i > 0 ? () => ctrl.move(i, i - 1) : null,
            onDown: i < prefs.length - 1 ? () => ctrl.move(i, i + 1) : null,
          ),
      ],
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({
    required this.label,
    required this.visible,
    required this.onToggle,
    required this.onUp,
    required this.onDown,
  });

  final String label;
  final bool visible;
  final VoidCallback onToggle;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.separator, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.headline.copyWith(
                color: visible ? AppColors.textPrimary : AppColors.textHint,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_upward, size: 18),
            color: AppColors.accent,
            onPressed: onUp,
            tooltip: 'Move up',
          ),
          IconButton(
            icon: const Icon(Icons.arrow_downward, size: 18),
            color: AppColors.accent,
            onPressed: onDown,
            tooltip: 'Move down',
          ),
          Switch.adaptive(value: visible, onChanged: (_) => onToggle()),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isCount = false,
  });

  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final bool isCount;

  @override
  Widget build(BuildContext context) {
    final display = isCount ? value.toStringAsFixed(0) : formatPkr(value);
    return SizedBox(
      width: (MediaQuery.of(context).size.width - AppSpacing.screenPadding * 2 - AppSpacing.md) / 2,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: AppTypography.footnote.copyWith(color: AppColors.textMuted)),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              display,
              style: AppTypography.title1.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentSaleRow extends StatelessWidget {
  const _RecentSaleRow({required this.sale});
  final RecentSale sale;

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(sale.createdAt);
    final timeStr = diff.inMinutes < 60
        ? '${diff.inMinutes}m ago'
        : diff.inHours < 24
            ? '${diff.inHours}h ago'
            : '${diff.inDays}d ago';
    final (color, label) = switch (sale.status.toUpperCase()) {
      'PAID' => (AppColors.success, 'PAID'),
      'PARTIALLY_PAID' => (AppColors.warning, 'PART'),
      'CONFIRMED' => (AppColors.accent, 'CREDIT'),
      'VOID' => (AppColors.textMuted, 'VOID'),
      _ => (AppColors.textHint, sale.status),
    };

    return InkWell(
      onTap: () => context.push('/sales/invoice/${sale.invoiceNumber}'),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.separator, width: 0.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sale.invoiceNumber, style: AppTypography.headline),
                  const SizedBox(height: 2),
                  Text(
                    '${sale.customer ?? 'Walk-in'} · $timeStr',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(label, style: AppTypography.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              formatPkr(sale.grandTotal),
              style: AppTypography.headline.copyWith(color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLaunch extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matrix = ref.watch(permissionMatrixProvider).value ?? <String>{};
    return Column(
      children: [
        Text('Quick Launch', style: AppTypography.title2),
        const SizedBox(height: AppSpacing.md),
        if (matrix.contains('sales:create'))
          _QuickButton(
            icon: Icons.point_of_sale,
            label: 'POS',
            onTap: () => context.go('/sales/pos'),
          ),
        if (matrix.contains('inventory:read'))
          _QuickButton(
            icon: Icons.inventory_2,
            label: 'Inventory',
            onTap: () => context.go('/inventory'),
          ),
        if (matrix.contains('sales:read'))
          _QuickButton(
            icon: Icons.history,
            label: 'Sales History',
            onTap: () => context.push('/sales/history'),
          ),
        if (matrix.contains('reports:read'))
          _QuickButton(
            icon: Icons.bar_chart,
            label: 'Reports',
            onTap: () => context.push('/reports'),
          ),
      ],
    );
  }
}

class _QuickButton extends StatelessWidget {
  const _QuickButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(label, style: AppTypography.headline),
                ),
                const Icon(Icons.chevron_right, color: AppColors.separator),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
