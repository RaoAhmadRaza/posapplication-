import '../../domain/entities/customer_ledger.dart';

class CustomerLedgerModel {
  static CustomerLedger fromJson(Map<String, dynamic> json) {
    final entries = (json['entries'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_entry)
        .toList();
    return CustomerLedger(
      customerId: json['customer_id'] as String? ?? '',
      openingBalance: _num(json['opening_balance']),
      currentBalance: _num(json['current_balance']),
      outstanding: _num(json['outstanding']),
      entries: entries,
    );
  }

  static CustomerLedgerEntry _entry(Map<String, dynamic> j) {
    return CustomerLedgerEntry(
      kind: j['kind'] as String? ?? '',
      reference: j['reference'] as String?,
      status: j['status'] as String?,
      debit: _num(j['debit']),
      credit: _num(j['credit']),
      runningBalance: _num(j['running_balance']),
      timestamp: DateTime.tryParse(j['ts']?.toString() ?? ''),
    );
  }

  static double _num(dynamic v) => double.tryParse(v.toString()) ?? 0;
}
