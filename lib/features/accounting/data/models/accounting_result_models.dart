import '../../domain/entities/accounting_results.dart';

class PostJournalResultModel {
  static PostJournalResult fromJson(Map<String, dynamic> json) {
    return PostJournalResult(
      journalEntryId: json['journal_entry_id'] as String,
      entryNumber: json['entry_number'] as String? ?? '',
      total: double.tryParse(json['total'].toString()) ?? 0,
    );
  }
}

class ReverseJournalResultModel {
  static ReverseJournalResult fromJson(Map<String, dynamic> json) {
    return ReverseJournalResult(
      journalEntryId: json['journal_entry_id'] as String,
      entryNumber: json['entry_number'] as String? ?? '',
    );
  }
}

class VoucherResultModel {
  static VoucherResult fromJson(Map<String, dynamic> json) {
    return VoucherResult(
      voucherId: json['voucher_id'] as String,
      voucherNumber: json['voucher_number'] as String? ?? '',
      journalEntryId: json['journal_entry_id'] as String?,
    );
  }
}

class ExpenseResultModel {
  static ExpenseResult fromJson(Map<String, dynamic> json) {
    return ExpenseResult(
      expenseId: json['expense_id'] as String,
      expenseNumber: json['expense_number'] as String?,
      journalEntryId: json['journal_entry_id'] as String?,
    );
  }
}
