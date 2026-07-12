import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/financial_reports.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadBalanceSheet {
  final AccountingRepository _repo;
  LoadBalanceSheet(this._repo);

  Future<(BalanceSheet?, AccountingFailure?)> call({
    DateTime? asOf,
    String? branchId,
  }) {
    return _repo.loadBalanceSheet(asOf: asOf, branchId: branchId);
  }
}

final loadBalanceSheetUseCaseProvider = Provider<LoadBalanceSheet>((ref) {
  return LoadBalanceSheet(ref.read(accountingRepositoryProvider));
});
