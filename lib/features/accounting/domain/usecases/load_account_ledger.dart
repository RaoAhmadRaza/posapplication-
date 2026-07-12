import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/account_ledger.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadAccountLedger {
  final AccountingRepository _repo;
  LoadAccountLedger(this._repo);

  Future<(AccountLedger?, AccountingFailure?)> call({
    required String accountId,
    DateTime? from,
    DateTime? to,
  }) {
    return _repo.loadAccountLedger(accountId: accountId, from: from, to: to);
  }
}

final loadAccountLedgerUseCaseProvider = Provider<LoadAccountLedger>((ref) {
  return LoadAccountLedger(ref.read(accountingRepositoryProvider));
});
