class Expense {
  final String id;
  final String tenantId;
  final String? branchId;
  final String? categoryId;
  final String? expenseNumber;
  final double amount;
  final double taxAmount;
  final DateTime expenseDate;
  final String? paymentMethod;
  final String? bankAccountId;
  final String? reference;
  final String? description;
  final String? journalEntryId;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.tenantId,
    this.branchId,
    this.categoryId,
    this.expenseNumber,
    required this.amount,
    required this.taxAmount,
    required this.expenseDate,
    this.paymentMethod,
    this.bankAccountId,
    this.reference,
    this.description,
    this.journalEntryId,
    required this.createdAt,
  });
}
