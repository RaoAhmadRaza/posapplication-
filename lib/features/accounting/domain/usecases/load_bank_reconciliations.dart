import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/bank_reconciliation.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadBankReconciliations {
  final AccountingRepository _repo;
  LoadBankReconciliations(this._repo);

  Future<(List<BankReconciliation>, AccountingFailure?)> call(
    String bankAccountId,
  ) {
    return _repo.loadBankReconciliations(bankAccountId);
  }
}

final loadBankReconciliationsUseCaseProvider =
    Provider<LoadBankReconciliations>((ref) {
  return LoadBankReconciliations(ref.read(accountingRepositoryProvider));
});
