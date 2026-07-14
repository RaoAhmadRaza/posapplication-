class SalaryAdvance {
  final String id;
  final String tenantId;
  final String employeeId;
  final double amount;
  final double balance;
  final double recoveryAmount;
  final DateTime disbursedAt;
  final DateTime? fullyRecoveredAt;
  final String? journalEntryId;
  final String? notes;

  const SalaryAdvance({
    required this.id,
    required this.tenantId,
    required this.employeeId,
    required this.amount,
    required this.balance,
    required this.recoveryAmount,
    required this.disbursedAt,
    this.fullyRecoveredAt,
    this.journalEntryId,
    this.notes,
  });

  bool get isFullyRecovered => balance <= 0;
}
