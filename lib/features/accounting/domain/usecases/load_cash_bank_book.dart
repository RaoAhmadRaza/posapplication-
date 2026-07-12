import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/account_ledger.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadCashBankBook {
  final AccountingRepository _repo;
  LoadCashBankBook(this._repo);

  Future<(AccountLedger?, AccountingFailure?)> call({
    required String accountCode,
    required DateTime from,
    required DateTime to,
  }) {
    return _repo.loadCashBankBook(
        accountCode: accountCode, from: from, to: to);
  }
}

final loadCashBankBookUseCaseProvider = Provider<LoadCashBankBook>((ref) {
  return LoadCashBankBook(ref.read(accountingRepositoryProvider));
});
