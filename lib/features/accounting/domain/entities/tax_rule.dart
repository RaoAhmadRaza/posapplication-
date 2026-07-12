enum TaxMode { inclusive, exclusive }

class TaxRule {
  final String id;
  final String tenantId;
  final String name;
  final String? code;
  final double rate;
  final TaxMode mode;
  final bool isDefault;
  final String? appliesTo;
  final String? description;
  final bool isActive;
  final DateTime? effectiveFrom;
  final DateTime? effectiveUntil;
  final DateTime createdAt;

  const TaxRule({
    required this.id,
    required this.tenantId,
    required this.name,
    this.code,
    required this.rate,
    required this.mode,
    required this.isDefault,
    this.appliesTo,
    this.description,
    required this.isActive,
    this.effectiveFrom,
    this.effectiveUntil,
    required this.createdAt,
  });
}
