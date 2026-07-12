class BankReconciliation {
  final String id;
  final String bankAccountId;
  final DateTime statementDate;
  final double statementBalance;
  final double ledgerBalance;
  final double reconciledBalance;
  final String status;
  final String? notes;
  final DateTime createdAt;

  const BankReconciliation({
    required this.id,
    required this.bankAccountId,
    required this.statementDate,
    required this.statementBalance,
    required this.ledgerBalance,
    required this.reconciledBalance,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  double get difference => statementBalance - ledgerBalance;
}
