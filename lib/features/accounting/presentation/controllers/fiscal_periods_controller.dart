import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/fiscal_period.dart';
import '../../domain/failures/accounting_failure.dart';
import '../../domain/usecases/close_fiscal_period.dart';
import '../../domain/usecases/load_fiscal_periods.dart';
import '../../domain/usecases/reopen_fiscal_period.dart';

final fiscalPeriodsProvider =
    AsyncNotifierProvider<FiscalPeriodsController, List<FiscalPeriod>>(
      FiscalPeriodsController.new,
    );

class FiscalPeriodsController extends AsyncNotifier<List<FiscalPeriod>> {
  @override
  Future<List<FiscalPeriod>> build() async {
    final (periods, failure) = await ref
        .read(loadFiscalPeriodsUseCaseProvider)
        .call();
    if (failure != null) throw failure;
    return periods;
  }

  void refresh() => ref.invalidateSelf();

  Future<AccountingFailure?> close(String id) async {
    final (_, failure) = await ref
        .read(closeFiscalPeriodUseCaseProvider)
        .call(id);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }

  Future<AccountingFailure?> reopen(String id) async {
    final (_, failure) = await ref
        .read(reopenFiscalPeriodUseCaseProvider)
        .call(id);
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }
}
