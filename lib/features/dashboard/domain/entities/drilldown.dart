/// Which KPI/summary a drilldown list is backing. Each maps to one drilldown_* RPC.
enum DrilldownType { sales, lowStock, receivables, payables, account, product }

/// A single row in a drilldown detail list, already shaped for display + deep-link.
class DrilldownRow {
  final String title;
  final String subtitle;
  final String trailing;
  final String? deepLink;

  const DrilldownRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.deepLink,
  });
}

/// Stable args for the drilldown provider family (value equality for caching).
class DrilldownArgs {
  final DrilldownType type;
  final String? branchId;
  final String? entityId; // product_id (uuid) or account_code
  final String? date; // ISO date for sales

  const DrilldownArgs(
    this.type, {
    this.branchId,
    this.entityId,
    this.date,
  });

  @override
  bool operator ==(Object other) =>
      other is DrilldownArgs &&
      other.type == type &&
      other.branchId == branchId &&
      other.entityId == entityId &&
      other.date == date;

  @override
  int get hashCode => Object.hash(type, branchId, entityId, date);
}
