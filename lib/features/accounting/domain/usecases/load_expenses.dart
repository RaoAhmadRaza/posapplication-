import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/expense.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadExpenses {
  final AccountingRepository _repo;
  LoadExpenses(this._repo);

  Future<(List<Expense>, AccountingFailure?)> call() {
    return _repo.loadExpenses();
  }
}

final loadExpensesUseCaseProvider = Provider<LoadExpenses>((ref) {
  return LoadExpenses(ref.read(accountingRepositoryProvider));
});
