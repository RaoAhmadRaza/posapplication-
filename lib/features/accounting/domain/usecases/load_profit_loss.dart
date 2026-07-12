import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/financial_reports.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadProfitLoss {
  final AccountingRepository _repo;
  LoadProfitLoss(this._repo);

  Future<(ProfitLoss?, AccountingFailure?)> call({
    required DateTime from,
    required DateTime to,
    String? branchId,
  }) {
    return _repo.loadProfitLoss(from: from, to: to, branchId: branchId);
  }
}

final loadProfitLossUseCaseProvider = Provider<LoadProfitLoss>((ref) {
  return LoadProfitLoss(ref.read(accountingRepositoryProvider));
});
