import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class ReopenFiscalPeriod {
  final AccountingRepository _repo;
  ReopenFiscalPeriod(this._repo);

  Future<(bool, AccountingFailure?)> call(String id) {
    return _repo.reopenFiscalPeriod(id);
  }
}

final reopenFiscalPeriodUseCaseProvider = Provider<ReopenFiscalPeriod>((ref) {
  return ReopenFiscalPeriod(ref.read(accountingRepositoryProvider));
});
