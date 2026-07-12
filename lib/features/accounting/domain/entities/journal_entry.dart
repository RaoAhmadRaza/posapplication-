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
  });
}
