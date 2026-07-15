import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/kpi_pref.dart';
import '../../domain/usecases/load_kpi_layout.dart';
import '../../domain/usecases/save_kpi_layout.dart';

// Re-export so existing importers (dashboard_page) keep the same import path.
export '../../domain/entities/kpi_pref.dart' show KpiPref, kpiKeysDefault;

/// Legacy per-device store (M08 stopgap, taken before ui_preferences existed).
/// Read ONCE to migrate an existing layout to the server on first run; never written.
const _legacyPrefsKey = 'dashboard_kpi_layout';

final kpiLayoutProvider =
    AsyncNotifierProvider<KpiLayoutController, List<KpiPref>>(
  KpiLayoutController.new,
);

/// KPI show/hide + order, persisted server-side per user via
/// ui_preferences.dashboard_layout_json (read on load, write on change).
class KpiLayoutController extends AsyncNotifier<List<KpiPref>> {
  LoadKpiLayout get _loadUseCase => ref.read(loadKpiLayoutUseCaseProvider);
  SaveKpiLayout get _saveUseCase => ref.read(saveKpiLayoutUseCaseProvider);

  @override
  Future<List<KpiPref>> build() async {
    final (server, _) = await _loadUseCase();
    if (server != null) return server;

    // No server layout yet — migrate an existing per-device layout up once so a
    // user's current KPI arrangement is not silently discarded.
    final legacy = await _readLegacyLayout();
    if (legacy != null) {
      await _saveUseCase(legacy); // failure tolerated: legacy shown, retried on next change
      return legacy;
    }
    return _defaults();
  }

  List<KpiPref> _defaults() =>
      kpiKeysDefault.map((k) => KpiPref(k, true)).toList();

  Future<List<KpiPref>?> _readLegacyLayout() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_legacyPrefsKey);
    if (saved == null || saved.isEmpty) return null;
    final parsed = <KpiPref>[];
    for (final entry in saved) {
      final parts = entry.split(':');
      if (parts.first.isNotEmpty) {
        parsed.add(KpiPref(parts.first, parts.length < 2 || parts[1] != '0'));
      }
    }
    return reconcileKpiLayout(parsed);
  }

  Future<void> _persist(List<KpiPref> next) async {
    state = AsyncData(next); // optimistic — layout is non-critical UX
    await _saveUseCase(next); // failure tolerated; next change retries
  }

  Future<void> toggle(String key) async {
    final current = state.value;
    if (current == null) return;
    await _persist([
      for (final p in current)
        p.key == key ? p.copyWith(visible: !p.visible) : p,
    ]);
  }

  Future<void> move(int oldIndex, int newIndex) async {
    final current = state.value;
    if (current == null) return;
    final next = List<KpiPref>.of(current);
    final item = next.removeAt(oldIndex);
    next.insert(newIndex.clamp(0, next.length), item);
    await _persist(next);
  }

  Future<void> reset() async => _persist(_defaults());
}
