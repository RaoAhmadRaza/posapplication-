import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/drilldown.dart';
import '../../domain/entities/kpi_pref.dart';
import '../failures/dashboard_failure.dart';

abstract class DashboardRepository {
  Future<(DashboardSummary, DashboardFailure?)> loadSummary({
    String? branchId,
    String? from,
    String? to,
  });

  Future<(List<DrilldownRow>, DashboardFailure?)> loadDrilldown(
    DrilldownArgs args,
  );

  /// Loads the saved KPI layout; a null layout means nothing is saved yet.
  Future<(List<KpiPref>?, DashboardFailure?)> loadKpiLayout();

  /// Persists the KPI layout. Returns a failure, or null on success.
  Future<DashboardFailure?> saveKpiLayout(List<KpiPref> layout);
}
