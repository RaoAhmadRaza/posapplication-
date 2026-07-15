import '../../domain/entities/kpi_pref.dart';

/// Maps the KPI layout to/from ui_preferences.dashboard_layout_json.
/// Stored as a JSON array of `{"k": key, "v": visible}` — list order = grid order.
class KpiLayoutModel {
  static List<Map<String, dynamic>> toJson(List<KpiPref> prefs) =>
      prefs.map((p) => {'k': p.key, 'v': p.visible}).toList();

  /// Parses stored layout (reconciled against the canonical key set).
  /// Returns null when nothing is saved server-side (raw is null).
  static List<KpiPref>? fromJson(List<dynamic>? raw) {
    if (raw == null) return null;
    final parsed = <KpiPref>[];
    for (final e in raw) {
      if (e is Map && e['k'] is String) {
        parsed.add(KpiPref(e['k'] as String, e['v'] != false));
      }
    }
    return reconcileKpiLayout(parsed);
  }
}
