import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/bank_account.dart';
import '../../domain/failures/accounting_failure.dart';
import '../../domain/usecases/create_bank_account.dart';
import '../../domain/usecases/load_bank_accounts.dart';
import '../../domain/usecases/update_bank_account.dart';

final bankAccountsProvider =
    AsyncNotifierProvider<BankAccountsController, List<BankAccount>>(
      BankAccountsController.new,
    );

class BankAccountsController extends AsyncNotifier<List<BankAccount>> {
  @override
  Future<List<BankAccount>> build() async {
    final (accounts, failure) = await ref
        .read(loadBankAccountsUseCaseProvider)
        .call();
    if (failure != null) throw failure;
    return accounts;
  }

  void refresh() => ref.invalidateSelf();

  Future<AccountingFailure?> create({
    required String accountName,
    required String bankName,
    required String accountNumber,
    String? iban,
    String? swiftCode,
    String? currency,
    double? openingBalance,
    required String chartAccountId,
    required bool isActive,
  }) async {
    final (_, failure) = await ref
        .read(createBankAccountUseCaseProvider)
        .call(
          accountName: accountName,
          bankName: bankName,
          accountNumber: accountNumber,
          iban: iban,
          swiftCode: swiftCode,
          currency: currency,
          openingBalance: openingBalance,
          chartAccountId: chartAccountId,
          isActive: isActive,
        );
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }

  Future<AccountingFailure?> edit(
    String id, {
    required String accountName,
    required String bankName,
    required String accountNumber,
    String? iban,
    String? swiftCode,
    String? currency,
    double? openingBalance,
    required String chartAccountId,
    required bool isActive,
  }) async {
    final (_, failure) = await ref
        .read(updateBankAccountUseCaseProvider)
        .call(
          id,
          accountName: accountName,
          bankName: bankName,
          accountNumber: accountNumber,
          iban: iban,
          swiftCode: swiftCode,
          currency: currency,
          openingBalance: openingBalance,
          chartAccountId: chartAccountId,
          isActive: isActive,
        );
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }
}
