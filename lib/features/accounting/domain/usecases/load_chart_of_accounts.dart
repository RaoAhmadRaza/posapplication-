import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/account.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadChartOfAccounts {
  final AccountingRepository _repo;
  LoadChartOfAccounts(this._repo);

  Future<(List<Account>, AccountingFailure?)> call() {
    return _repo.loadChartOfAccounts();
  }
}

final loadChartOfAccountsUseCaseProvider = Provider<LoadChartOfAccounts>((ref) {
  return LoadChartOfAccounts(ref.read(accountingRepositoryProvider));
});
