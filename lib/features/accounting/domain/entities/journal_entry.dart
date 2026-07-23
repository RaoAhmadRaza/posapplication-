class JournalEntry {
  final String id;
  final String tenantId;
  final String entryNumber;
  final String? referenceId;
  final String? referenceType;
  final String? description;
  final String? periodId;
  final String? branchId;
  final bool isReversing;
  final String? reversedEntryId;
  final String? postedBy;
  final String? correlationId;
  final DateTime createdAt;

  /// Posted total (sum of debits = sum of credits). 0 when read from a source
  /// that doesn't supply it (e.g. the single-entry detail read).
  final double total;

  const JournalEntry({
    required this.id,
    required this.tenantId,
    required this.entryNumber,
    this.referenceId,
    this.referenceType,
    this.description,
    this.periodId,
    this.branchId,
    required this.isReversing,
    this.reversedEntryId,
    this.postedBy,
    this.correlationId,
    required this.createdAt,
    this.total = 0,
  });
}
