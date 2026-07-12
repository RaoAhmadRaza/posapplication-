import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/reconciliation_result.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class CreateBankReconciliation {
  final AccountingRepository _repo;
  CreateBankReconciliation(this._repo);

  Future<(ReconciliationResult?, AccountingFailure?)> call({
    required String bankAccountId,
    required DateTime statementDate,
    required double statementBalance,
    String? notes,
  }) {
    return _repo.createBankReconciliation(
      bankAccountId: bankAccountId,
      statementDate: statementDate,
      statementBalance: statementBalance,
      notes: notes,
    );
  }
}

final createBankReconciliationUseCaseProvider =
    Provider<CreateBankReconciliation>((ref) {
  return CreateBankReconciliation(ref.read(accountingRepositoryProvider));
});
