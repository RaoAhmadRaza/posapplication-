import '../../domain/entities/journal_entry.dart';

class JournalEntryModel {
  static JournalEntry fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      entryNumber: json['entry_number'] as String,
      referenceId: json['reference_id'] as String?,
      referenceType: json['reference_type'] as String?,
      description: json['description'] as String?,
      periodId: json['period_id'] as String?,
      branchId: json['branch_id'] as String?,
      isReversing: json['is_reversing'] as bool? ?? false,
      reversedEntryId: json['reversed_entry_id'] as String?,
      postedBy: json['posted_by'] as String?,
      correlationId: json['correlation_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
