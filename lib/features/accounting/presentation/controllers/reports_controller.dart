import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/account_ledger.dart';
import '../../domain/entities/financial_reports.dart';
import '../../domain/usecases/load_balance_sheet.dart';
import '../../domain/usecases/load_cash_bank_book.dart';
import '../../domain/usecases/load_profit_loss.dart';
import '../../domain/usecases/load_trial_balance.dart';

typedef AsOfArgs = ({DateTime? asOf, String? branchId});
typedef RangeArgs = ({DateTime from, DateTime to, String? branchId});
typedef CashBookArgs = ({String accountCode, DateTime from, DateTime to});

final trialBalanceProvider = FutureProvider.autoDispose
    .family<TrialBalance, AsOfArgs>((ref, args) async {
  final (report, failure) = await ref
      .read(loadTrialBalanceUseCaseProvider)
      .call(asOf: args.asOf, branchId: args.branchId);
  if (failure != null) throw failure;
  return report!;
});

final profitLossProvider = FutureProvider.autoDispose
    .family<ProfitLoss, RangeArgs>((ref, args) async {
  final (report, failure) = await ref
      .read(loadProfitLossUseCaseProvider)
      .call(from: args.from, to: args.to, branchId: args.branchId);
  if (failure != null) throw failure;
  return report!;
});

final balanceSheetProvider = FutureProvider.autoDispose
    .family<BalanceSheet, AsOfArgs>((ref, args) async {
  final (report, failure) = await ref
      .read(loadBalanceSheetUseCaseProvider)
      .call(asOf: args.asOf, branchId: args.branchId);
  if (failure != null) throw failure;
  return report!;
});

final cashBankBookProvider = FutureProvider.autoDispose
    .family<AccountLedger, CashBookArgs>((ref, args) async {
  final (book, failure) = await ref
      .read(loadCashBankBookUseCaseProvider)
      .call(accountCode: args.accountCode, from: args.from, to: args.to);
  if (failure != null) throw failure;
  return book!;
});
