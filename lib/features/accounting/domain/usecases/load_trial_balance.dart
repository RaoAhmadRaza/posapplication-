import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/financial_reports.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadTrialBalance {
  final AccountingRepository _repo;
  LoadTrialBalance(this._repo);

  Future<(TrialBalance?, AccountingFailure?)> call({
    DateTime? asOf,
    String? branchId,
  }) {
    return _repo.loadTrialBalance(asOf: asOf, branchId: branchId);
  }
}

final loadTrialBalanceUseCaseProvider = Provider<LoadTrialBalance>((ref) {
  return LoadTrialBalance(ref.read(accountingRepositoryProvider));
});
