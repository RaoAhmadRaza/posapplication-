import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../controllers/kpi_layout_controller.dart';
import '../pages/dashboard_page.dart' show dashboardEditingProvider;
import 'dashboard_layout.dart';
import 'kpi_descriptors.dart';
import 'kpi_tile.dart';

/// The configurable KPI grid. Order and visibility come from [kpiLayoutProvider];
/// edit mode adds per-tile controls rather than a separate list.
class KpiGrid extends ConsumerWidget {
  const KpiGrid({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(kpiLayoutProvider).value ??
        kpiKeysDefault.map((k) => KpiPref(k, true)).toList();
    final editing = ref.watch(dashboardEditingProvider);
    final metrics = DashboardMetrics.of(context);

    // Edit mode shows every card (dimmed when hidden) so it can be toggled back.
    final entries = [
      for (var i = 0; i < prefs.length; i++)
        if (kpiDescriptors[prefs[i].key] != null && (editing || prefs[i].visible))
          (index: i, pref: prefs[i], desc: kpiDescriptors[prefs[i].key]!),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (editing) ...[
          const _EditBanner(),
          SizedBox(height: metrics.gap),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            // Derive the ratio from the real cell width so tiles end up the
            // height of their content — a guessed ratio leaves dead space.
            final cols = metrics.kpiCols;
            final cellWidth =
                (constraints.maxWidth - _spacing * (cols - 1)) / cols;
            final height = editing ? _tileHeight + _footerHeight : _tileHeight;
            return GridView.count(
              crossAxisCount: cols,
              crossAxisSpacing: _spacing,
              mainAxisSpacing: _spacing,
              childAspectRatio: cellWidth / height,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final e in entries)
                  _GridEntry(
                    summary: summary,
                    desc: e.desc,
                    pref: e.pref,
                    index: e.index,
                    total: prefs.length,
                    editing: editing,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  static const _spacing = 10.0;

  /// 15 pad + 16 label + 11 + 26 value + 5 + 32 (two-line sub) + 15 pad.
  static const _tileHeight = 120.0;

  /// 12 margin + 11 pad + 30 button.
  static const _footerHeight = 53.0;
}

class _GridEntry extends ConsumerWidget {
  const _GridEntry({
    required this.summary,
    required this.desc,
    required this.pref,
    required this.index,
    required this.total,
    required this.editing,
  });

  final DashboardSummary summary;
  final KpiDesc desc;
  final KpiPref pref;
  final int index;
  final int total;
  final bool editing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final ctrl = ref.read(kpiLayoutProvider.notifier);

    // today_sales is the one KPI with a genuinely derivable day-over-day change.
    final delta = pref.key == 'today_sales' ? todaySalesDelta(summary) : null;

    final tile = KpiTile(
      label: desc.label,
      value: desc.value(summary),
      icon: desc.icon,
      iconColor: desc.iconColor(lum),
      isCount: desc.isCount,
      subLabel: delta == null
          ? desc.subLabel
          : '${delta.pct.toStringAsFixed(1)}% vs yesterday',
      trend: delta == null
          ? KpiTrend.none
          : (delta.up ? KpiTrend.up : KpiTrend.down),
      trendIsGood: delta?.up ?? true,
      dimmed: editing && !pref.visible,
      editFooter: editing
          ? KpiEditFooter(
              visible: pref.visible,
              onToggle: () => ctrl.toggle(pref.key),
              onUp: index > 0 ? () => ctrl.move(index, index - 1) : null,
              onDown:
                  index < total - 1 ? () => ctrl.move(index, index + 1) : null,
            )
          : null,
    );

    // Taps are inert while editing — the footer owns interaction there.
    if (editing) return tile;

    final branchId = ref.read(currentBranchProvider)?.id;
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final nav = desc.drill?.call(branchId, date);
    final VoidCallback? onTap = nav != null
        ? () => context.push('/dashboard/drilldown', extra: nav)
        : (desc.route != null ? () => context.push(desc.route!) : null);
    if (onTap == null) return tile;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: tile,
    );
  }
}

class _EditBanner extends StatelessWidget {
  const _EditBanner();

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: lum.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.gripVertical, size: 16, color: lum.accentPress),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'Editing layout — hide cards or move them. '
              'Tap the check to save.',
              style: AppTypography.caption.copyWith(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: lum.accentPress,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
