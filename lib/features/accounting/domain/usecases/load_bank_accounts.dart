import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/bank_account.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadBankAccounts {
  final AccountingRepository _repo;
  LoadBankAccounts(this._repo);

  Future<(List<BankAccount>, AccountingFailure?)> call() {
    return _repo.loadBankAccounts();
  }
}

final loadBankAccountsUseCaseProvider = Provider<LoadBankAccounts>((ref) {
  return LoadBankAccounts(ref.read(accountingRepositoryProvider));
});
