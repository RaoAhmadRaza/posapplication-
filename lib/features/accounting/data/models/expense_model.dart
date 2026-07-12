import '../../domain/entities/expense.dart';

class ExpenseModel {
  static Expense fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String?,
      categoryId: json['category_id'] as String?,
      expenseNumber: json['expense_number'] as String?,
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      taxAmount: double.tryParse(json['tax_amount'].toString()) ?? 0,
      expenseDate: DateTime.parse(json['expense_date'] as String),
      paymentMethod: json['payment_method'] as String?,
      bankAccountId: json['bank_account_id'] as String?,
      reference: json['reference'] as String?,
      description: json['description'] as String?,
      journalEntryId: json['journal_entry_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
