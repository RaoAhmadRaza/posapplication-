class JournalLine {
  final String id;
  final String journalEntryId;
  final String accountId;
  final double debit;
  final double credit;
  final String? narration;
  final String? branchId;
  final DateTime createdAt;

  const JournalLine({
    required this.id,
    required this.journalEntryId,
    required this.accountId,
    required this.debit,
    required this.credit,
    this.narration,
    this.branchId,
    required this.createdAt,
  });
}
