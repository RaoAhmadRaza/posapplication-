import '../../domain/entities/bank_reconciliation.dart';

class BankReconciliationModel {
  static BankReconciliation fromJson(Map<String, dynamic> json) {
    return BankReconciliation(
      id: json['id'] as String,
      bankAccountId: json['bank_account_id'] as String,
      statementDate: _date(json['statement_date']),
      statementBalance: _num(json['statement_balance']),
      ledgerBalance: _num(json['ledger_balance']),
      reconciledBalance: _num(json['reconciled_balance']),
      status: json['status'] as String? ?? 'DRAFT',
      notes: json['notes'] as String?,
      createdAt: _date(json['created_at']),
    );
  }

  static double _num(Object? v) => double.tryParse(v.toString()) ?? 0;

  static DateTime _date(Object? v) =>
      DateTime.tryParse(v.toString())?.toLocal() ?? DateTime.now();
}
