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

/// One KPI card's layout state: its key + whether it is shown. List order = grid order.
class KpiPref {
  final String key;
  final bool visible;
  const KpiPref(this.key, this.visible);

  KpiPref copyWith({bool? visible}) => KpiPref(key, visible ?? this.visible);
}

/// Dedups by key, drops unknown keys, then appends any new default keys (visible)
/// not yet present — forward-compat when the canonical KPI set grows.
List<KpiPref> reconcileKpiLayout(Iterable<KpiPref> parsed) {
  final out = <KpiPref>[];
  for (final p in parsed) {
    if (kpiKeysDefault.contains(p.key) && !out.any((x) => x.key == p.key)) {
      out.add(p);
    }
  }
  for (final k in kpiKeysDefault) {
    if (!out.any((x) => x.key == k)) out.add(KpiPref(k, true));
  }
  return out;
}
