import 'package:flutter/widgets.dart';

/// Width at or above which the dashboard uses its wide layout. Matches the nav
/// shell's rail breakpoint so the rail and the 5-column grid appear together.
const kDashboardWideBreakpoint = 900.0;

/// Breakpoint-derived metrics for the dashboard body, so every section lays out
/// against the same numbers instead of each re-deriving them.
class DashboardMetrics {
  const DashboardMetrics._({
    required this.isWide,
    required this.kpiCols,
    required this.pad,
    required this.gap,
    required this.maxWidth,
  });

  factory DashboardMetrics.of(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= kDashboardWideBreakpoint;
    return wide
        ? const DashboardMetrics._(
            isWide: true,
            kpiCols: 5,
            pad: EdgeInsets.all(28),
            gap: 20,
            maxWidth: 1180,
          )
        : const DashboardMetrics._(
            isWide: false,
            kpiCols: 2,
            pad: EdgeInsets.fromLTRB(16, 16, 16, 28),
            gap: 14,
            maxWidth: double.infinity,
          );
  }

  final bool isWide;

  /// Columns in the KPI grid.
  final int kpiCols;
  final EdgeInsets pad;

  /// Vertical gap between body sections.
  final double gap;
  final double maxWidth;

  /// Charts and the recent-sales/quick-launch row sit side by side only when
  /// wide; below the breakpoint every section stacks full width.
  bool get isSideBySide => isWide;
}
