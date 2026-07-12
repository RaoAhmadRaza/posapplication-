import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/fiscal_period.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class LoadFiscalPeriods {
  final AccountingRepository _repo;
  LoadFiscalPeriods(this._repo);

  Future<(List<FiscalPeriod>, AccountingFailure?)> call() {
    return _repo.loadFiscalPeriods();
  }
}

final loadFiscalPeriodsUseCaseProvider = Provider<LoadFiscalPeriods>((ref) {
  return LoadFiscalPeriods(ref.read(accountingRepositoryProvider));
});
