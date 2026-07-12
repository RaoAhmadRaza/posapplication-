import '../../domain/entities/account_ledger.dart';

class AccountLedgerModel {
  static AccountLedger fromJson(Map<String, dynamic> json) {
    final entries = (json['entries'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_entry)
        .toList();
    return AccountLedger(
      accountId: json['account_id'] as String? ?? '',
      openingBalance: _num(json['opening_balance']),
      entries: entries,
    );
  }

  static AccountLedgerEntry _entry(Map<String, dynamic> j) {
    return AccountLedgerEntry(
      date: DateTime.tryParse((j['date'] ?? j['created_at'])?.toString() ?? ''),
      entryNumber: j['entry_number'] as String?,
      description: j['description'] as String?,
      debit: _num(j['debit']),
      credit: _num(j['credit']),
      runningBalance: _num(j['running_balance']),
    );
  }

  static double _num(dynamic v) => double.tryParse(v.toString()) ?? 0;
}
