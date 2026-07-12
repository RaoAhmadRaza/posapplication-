import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/expense_category.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadExpenseCategories {
  final AccountingRepository _repo;
  LoadExpenseCategories(this._repo);

  Future<(List<ExpenseCategory>, AccountingFailure?)> call() {
    return _repo.loadExpenseCategories();
  }
}

final loadExpenseCategoriesUseCaseProvider = Provider<LoadExpenseCategories>((
  ref,
) {
  return LoadExpenseCategories(ref.read(accountingRepositoryProvider));
});
