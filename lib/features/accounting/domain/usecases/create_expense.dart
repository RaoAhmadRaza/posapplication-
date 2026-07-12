import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/accounting_results.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class CreateExpense {
  final AccountingRepository _repo;
  CreateExpense(this._repo);

  Future<(ExpenseResult?, AccountingFailure?)> call({
    required String branchId,
    required String categoryId,
    required double amount,
    required double taxAmount,
    required DateTime expenseDate,
    required String paymentMethod,
    String? bankAccountId,
    String? reference,
    required String description,
  }) {
    return _repo.createExpense(
      branchId: branchId,
      categoryId: categoryId,
      amount: amount,
      taxAmount: taxAmount,
      expenseDate: expenseDate,
      paymentMethod: paymentMethod,
      bankAccountId: bankAccountId,
      reference: reference,
      description: description,
    );
  }
}

final createExpenseUseCaseProvider = Provider<CreateExpense>((ref) {
  return CreateExpense(ref.read(accountingRepositoryProvider));
});
