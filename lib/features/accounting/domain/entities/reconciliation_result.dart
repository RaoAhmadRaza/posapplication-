class ReconciliationResult {
  final String reconciliationId;
  final double ledgerBalance;
  final double statementBalance;
  final double difference;

  const ReconciliationResult({
    required this.reconciliationId,
    required this.ledgerBalance,
    required this.statementBalance,
    required this.difference,
  });
}
