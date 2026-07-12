import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class CloseFiscalPeriod {
  final AccountingRepository _repo;
  CloseFiscalPeriod(this._repo);

  Future<(bool, AccountingFailure?)> call(String id) {
    return _repo.closeFiscalPeriod(id);
  }
}

final closeFiscalPeriodUseCaseProvider = Provider<CloseFiscalPeriod>((ref) {
  return CloseFiscalPeriod(ref.read(accountingRepositoryProvider));
});
