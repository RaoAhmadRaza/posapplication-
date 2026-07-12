enum FiscalPeriodStatus { open, closed, locked }

class FiscalPeriod {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final FiscalPeriodStatus status;
  final DateTime? closedAt;

  const FiscalPeriod({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.status,
    this.closedAt,
  });

  bool get isCurrent {
    final now = DateTime.now();
    return !now.isBefore(startDate) && !now.isAfter(endDate);
  }
}
