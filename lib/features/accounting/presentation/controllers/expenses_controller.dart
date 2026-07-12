import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_category.dart';
import '../../domain/failures/accounting_failure.dart';
import '../../domain/usecases/create_expense.dart';
import '../../domain/usecases/create_expense_category.dart';
import '../../domain/usecases/load_expense_categories.dart';
import '../../domain/usecases/load_expenses.dart';

final expensesProvider =
    AsyncNotifierProvider<ExpensesController, List<Expense>>(
      ExpensesController.new,
    );

class ExpensesController extends AsyncNotifier<List<Expense>> {
  @override
  Future<List<Expense>> build() async {
    final (expenses, failure) = await ref
        .read(loadExpensesUseCaseProvider)
        .call();
    if (failure != null) throw failure;
    return expenses;
  }

  void refresh() => ref.invalidateSelf();

  Future<AccountingFailure?> createExpense({
    required String branchId,
    required String categoryId,
    required double amount,
    required double taxAmount,
    required DateTime expenseDate,
    required String paymentMethod,
    String? bankAccountId,
    String? reference,
    required String description,
  }) async {
    final (_, failure) = await ref
        .read(createExpenseUseCaseProvider)
        .call(
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
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }

  Future<AccountingFailure?> createCategory({
    required String name,
    required String accountId,
    String? parentId,
    String? description,
  }) async {
    final (_, failure) = await ref
        .read(createExpenseCategoryUseCaseProvider)
        .call(
          name: name,
          accountId: accountId,
          parentId: parentId,
          description: description,
        );
    if (failure != null) return failure;
    ref.invalidate(expenseCategoriesProvider);
    return null;
  }
}

final expenseCategoriesProvider =
    AsyncNotifierProvider<ExpenseCategoriesController, List<ExpenseCategory>>(
      ExpenseCategoriesController.new,
    );

class ExpenseCategoriesController extends AsyncNotifier<List<ExpenseCategory>> {
  @override
  Future<List<ExpenseCategory>> build() async {
    final (categories, failure) = await ref
        .read(loadExpenseCategoriesUseCaseProvider)
        .call();
    if (failure != null) throw failure;
    return categories;
  }

  void refresh() => ref.invalidateSelf();
}
