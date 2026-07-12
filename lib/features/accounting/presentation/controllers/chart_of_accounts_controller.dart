import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/account_ledger.dart';
import '../../domain/usecases/load_account_ledger.dart';
import '../../domain/usecases/load_chart_of_accounts.dart';

final chartOfAccountsProvider =
    AsyncNotifierProvider<ChartOfAccountsController, List<Account>>(
      ChartOfAccountsController.new,
    );

class ChartOfAccountsController extends AsyncNotifier<List<Account>> {
  @override
  Future<List<Account>> build() async {
    final (accounts, failure) = await ref
        .read(loadChartOfAccountsUseCaseProvider)
        .call();
    if (failure != null) throw failure;
    return accounts;
  }

  void refresh() => ref.invalidateSelf();
}

/// Per-account ledger for the detail view (opening balance + running lines).
final accountLedgerProvider = FutureProvider.autoDispose
    .family<AccountLedger, String>((ref, id) async {
      final (ledger, failure) = await ref
          .read(loadAccountLedgerUseCaseProvider)
          .call(accountId: id);
      if (failure != null) throw failure;
      return ledger!;
    });
