import '../../domain/entities/supplier_ledger.dart';

class SupplierLedgerModel {
  static SupplierLedger fromJson(Map<String, dynamic> json) {
    final entries = (json['entries'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_entry)
        .toList();
    return SupplierLedger(
      supplierId: json['supplier_id'] as String? ?? '',
      openingBalance: _num(json['opening_balance']),
      currentBalance: _num(json['current_balance']),
      entries: entries,
    );
  }

  static SupplierLedgerEntry _entry(Map<String, dynamic> j) {
    return SupplierLedgerEntry(
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
