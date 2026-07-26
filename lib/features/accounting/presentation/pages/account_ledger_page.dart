import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../domain/entities/account.dart';
import '../controllers/chart_of_accounts_controller.dart';
import '../widgets/acct_date_field.dart';
import '../widgets/acct_ledger_table.dart';

class AccountLedgerPage extends ConsumerWidget {
  const AccountLedgerPage({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(accountLedgerProvider(accountId));

    // The ledger DTO carries no name/code, so resolve them from the already
    // loaded chart of accounts when available.
    final account = ref.watch(chartOfAccountsProvider).maybeWhen(
          data: (accounts) => accounts
              .cast<Account?>()
              .firstWhere((a) => a?.id == accountId, orElse: () => null),
          orElse: () => null,
        );
    final title = account == null
        ? 'Account ledger'
        : '${account.code} · ${account.name}';

    return AppDetailScaffold(
      eyebrow: 'Accounting',
      title: title,
      child: state.when(
        loading: () => const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.only(top: 30),
          child: AppErrorState(
            title: 'Unable to load ledger',
            body: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(accountLedgerProvider(accountId)),
          ),
        ),
        data: (ledger) => AcctLedgerCard(
          openingBalance: ledger.openingBalance,
          rows: [
            for (final e in ledger.entries)
              AcctLedgerRow(
                date: e.date == null ? '—' : acctFormatDateShort(e.date!),
                particulars: e.description ?? '—',
                reference: e.entryNumber,
                debit: e.debit,
                credit: e.credit,
                balance: e.runningBalance,
              ),
          ],
        ),
      ),
    );
  }
}
