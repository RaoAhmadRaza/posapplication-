import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Canonical KPI keys in default order (all shown by default).
const kpiKeysDefault = <String>[
  'today_sales',
  'today_txns',
  'today_profit',
  'receivables',
  'stock_value',
  'low_stock',
  'payables',
  'cash',
  'bank',
  'pl',
];

const _prefsKey = 'dashboard_kpi_layout';

/// One KPI card's layout state: its key + whether it is shown. List order = grid order.
class KpiPref {
  final String key;
  final bool visible;
  const KpiPref(this.key, this.visible);

  KpiPref copyWith({bool? visible}) => KpiPref(key, visible ?? this.visible);
}

final kpiLayoutProvider =
    AsyncNotifierProvider<KpiLayoutController, List<KpiPref>>(
  KpiLayoutController.new,
);

/// Persists KPI show/hide + order in shared_preferences (per device).
/// Stored as a string list of "key:1" (visible) / "key:0" (hidden) entries.
class KpiLayoutController extends AsyncNotifier<List<KpiPref>> {
  @override
  Future<List<KpiPref>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey);
    if (saved == null || saved.isEmpty) {
      return kpiKeysDefault.map((k) => KpiPref(k, true)).toList();
    }
    final parsed = <KpiPref>[];
    for (final entry in saved) {
      final parts = entry.split(':');
      final key = parts.first;
      if (kpiKeysDefault.contains(key) && !parsed.any((p) => p.key == key)) {
        parsed.add(KpiPref(key, parts.length < 2 || parts[1] != '0'));
      }
    }
    // Forward-compat: append any new default keys not yet persisted (visible).
    for (final k in kpiKeysDefault) {
      if (!parsed.any((p) => p.key == k)) parsed.add(KpiPref(k, true));
    }
    return parsed;
  }

  Future<void> _persist(List<KpiPref> next) async {
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      next.map((p) => '${p.key}:${p.visible ? 1 : 0}').toList(),
    );
  }

  Future<void> toggle(String key) async {
    final current = state.value;
    if (current == null) return;
    await _persist([
      for (final p in current) p.key == key ? p.copyWith(visible: !p.visible) : p,
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

  Future<void> reset() async => _persist(
        kpiKeysDefault.map((k) => KpiPref(k, true)).toList(),
      );
}
