class BankAccount {
  final String id;
  final String tenantId;
  final String? branchId;
  final String accountName;
  final String? bankName;
  final String? accountNumber;
  final String? iban;
  final String? swiftCode;
  final String? currency;
  final double openingBalance;
  final double currentBalance;
  final String? chartAccountId;
  final bool isActive;
  final DateTime createdAt;

  const BankAccount({
    required this.id,
    required this.tenantId,
    this.branchId,
    required this.accountName,
    this.bankName,
    this.accountNumber,
    this.iban,
    this.swiftCode,
    this.currency,
    required this.openingBalance,
    required this.currentBalance,
    this.chartAccountId,
    required this.isActive,
    required this.createdAt,
  });
}
