import '../../domain/entities/journal_line.dart';

class JournalLineModel {
  static JournalLine fromJson(Map<String, dynamic> json) {
    return JournalLine(
      id: json['id'] as String,
      journalEntryId: json['journal_entry_id'] as String,
      accountId: json['account_id'] as String,
      debit: double.tryParse(json['debit'].toString()) ?? 0,
      credit: double.tryParse(json['credit'].toString()) ?? 0,
      narration: json['narration'] as String?,
      branchId: json['branch_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
