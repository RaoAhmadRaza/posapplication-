import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class CompleteBankReconciliation {
  final AccountingRepository _repo;
  CompleteBankReconciliation(this._repo);

  Future<(bool, AccountingFailure?)> call({
    required String reconciliationId,
    required double reconciledBalance,
    String? notes,
  }) {
    return _repo.completeBankReconciliation(
      reconciliationId: reconciliationId,
      reconciledBalance: reconciledBalance,
      notes: notes,
    );
  }
}

final completeBankReconciliationUseCaseProvider =
    Provider<CompleteBankReconciliation>((ref) {
  return CompleteBankReconciliation(ref.read(accountingRepositoryProvider));
});
