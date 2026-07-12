import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/expense_category.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class CreateExpenseCategory {
  final AccountingRepository _repo;
  CreateExpenseCategory(this._repo);

  Future<(ExpenseCategory?, AccountingFailure?)> call({
    required String name,
    required String accountId,
    String? parentId,
    String? description,
  }) {
    return _repo.createExpenseCategory(
      name: name,
      accountId: accountId,
      parentId: parentId,
      description: description,
    );
  }
}

final createExpenseCategoryUseCaseProvider = Provider<CreateExpenseCategory>((
  ref,
) {
  return CreateExpenseCategory(ref.read(accountingRepositoryProvider));
});
