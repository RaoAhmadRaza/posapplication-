// Typed results from the mutating RPCs (each returns a single jsonb Map).

class PostJournalResult {
  final String journalEntryId;
  final String entryNumber;
  final double total;
  const PostJournalResult({
    required this.journalEntryId,
    required this.entryNumber,
    required this.total,
  });
}

class ReverseJournalResult {
  final String journalEntryId;
  final String entryNumber;
  const ReverseJournalResult({
    required this.journalEntryId,
    required this.entryNumber,
  });
}

class VoucherResult {
  final String voucherId;
  final String voucherNumber;
  final String? journalEntryId;
  const VoucherResult({
    required this.voucherId,
    required this.voucherNumber,
    this.journalEntryId,
  });
}

class ExpenseResult {
  final String expenseId;
  final String? expenseNumber;
  final String? journalEntryId;
  const ExpenseResult({
    required this.expenseId,
    this.expenseNumber,
    this.journalEntryId,
  });
}
