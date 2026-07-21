import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../../../core/supabase.dart';
import '../../../../core/widgets/permission_gate.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/dashboard_app_bar.dart';
import '../widgets/dashboard_layout.dart';
import '../widgets/kpi_descriptors.dart';
import '../widgets/kpi_grid.dart';
import '../widgets/payment_methods_card.dart';
import '../widgets/quick_launch.dart';
import '../widgets/recent_sales_card.dart';
import '../widgets/sales_trend_card.dart';
import '../widgets/welcome_card.dart';

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
      fallback: const _NoAccess(),
      child: const _DashboardScaffold(),
    );
  }
}

class _DashboardScaffold extends ConsumerWidget {
  const _DashboardScaffold();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final metrics = DashboardMetrics.of(context);
    final state = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: lum.paper,
      appBar: DashboardAppBar(isWide: metrics.isWide),
      body: RefreshIndicator(
        onRefresh: () => ref.read(dashboardProvider.notifier).refresh(),
        child: switch (state) {
          AsyncValue(hasError: true) => _ErrorBody(
              onRetry: () => ref.read(dashboardProvider.notifier).refresh(),
              metrics: metrics,
            ),
          AsyncValue(:final value?) => _Body(summary: value, metrics: metrics),
          _ => _LoadingBody(metrics: metrics),
        },
      ),
    );
  }
}

/// The dashboard body. Sections stack on narrow layouts and pair up on wide.
class _Body extends ConsumerWidget {
  const _Body({required this.summary, required this.metrics});

  final DashboardSummary summary;
  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gap = metrics.gap;
    // Both chart cards always render — a tenant with no sales yet should still
    // see the dashboard's shape, with an empty state inside the card.
    final trend = SalesTrendCard(points: summary.salesTrend);
    final payments = PaymentMethodsCard(breakdown: summary.paymentBreakdown);
    final recent = summary.recentSales.isEmpty
        ? null
        : RecentSalesCard(sales: summary.recentSales, viewAll: _viewAllSales());

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: metrics.pad,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: metrics.maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WelcomeCard(fallbackName: supabase.auth.currentUser?.email),
                SizedBox(height: gap),
                KpiGrid(summary: summary),
                SizedBox(height: gap),
                _Pair(
                  metrics: metrics,
                  leadingFlex: 16,
                  trailingFlex: 10,
                  leading: trend,
                  trailing: payments,
                ),
                SizedBox(height: gap),
                _Pair(
                  metrics: metrics,
                  leadingFlex: 15,
                  trailingFlex: 10,
                  leading: recent,
                  trailing: const QuickLaunch(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 'View all' opens the same sales list the today's-sales KPI drills into.
  DrilldownNav? _viewAllSales() {
    final desc = kpiDescriptors['today_sales'];
    return desc?.drill?.call(
      null,
      DateTime.now().toIso8601String().substring(0, 10),
    );
  }
}

/// Two sections side by side when wide, stacked when narrow. Either may be null.
class _Pair extends StatelessWidget {
  const _Pair({
    required this.metrics,
    required this.leading,
    required this.trailing,
    required this.leadingFlex,
    required this.trailingFlex,
  });

  final DashboardMetrics metrics;
  final Widget? leading;
  final Widget? trailing;
  final int leadingFlex;
  final int trailingFlex;

  @override
  Widget build(BuildContext context) {
    if (leading == null) return trailing ?? const SizedBox.shrink();
    if (trailing == null) return leading!;

    if (!metrics.isSideBySide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [leading!, SizedBox(height: metrics.gap), trailing!],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: leadingFlex, child: leading!),
        SizedBox(width: metrics.gap),
        Expanded(flex: trailingFlex, child: trailing!),
      ],
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody({required this.metrics});

  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: metrics.pad,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: lum.accent,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Refreshing…',
              style: AppTypography.caption.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: lum.g500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.onRetry, required this.metrics});

  final VoidCallback onRetry;
  final DashboardMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: metrics.pad,
      children: [
        AppInlineBanner(
          message: 'Could not load dashboard.',
          type: BannerType.error,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Retry',
          onPressed: onRetry,
          variant: AppButtonVariant.plain,
        ),
      ],
    );
  }
}

class _NoAccess extends StatelessWidget {
  const _NoAccess();

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Scaffold(
      backgroundColor: lum.paper,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.lock, size: 48, color: lum.g400),
              const SizedBox(height: 16),
              Text(
                'No access to reports.',
                style: AppTypography.subhead.copyWith(color: lum.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
