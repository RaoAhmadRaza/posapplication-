import '../../domain/entities/reconciliation_result.dart';

class ReconciliationResultModel {
  static ReconciliationResult fromJson(Map<String, dynamic> json) {
    return ReconciliationResult(
      reconciliationId: json['reconciliation_id'] as String,
      ledgerBalance: _num(json['ledger_balance']),
      statementBalance: _num(json['statement_balance']),
      difference: _num(json['difference']),
    );
  }

  static double _num(Object? v) => double.tryParse(v.toString()) ?? 0;
}
