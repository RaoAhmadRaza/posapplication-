import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/bank_account.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class UpdateBankAccount {
  final AccountingRepository _repo;
  UpdateBankAccount(this._repo);

  Future<(BankAccount?, AccountingFailure?)> call(
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
  }) {
    return _repo.updateBankAccount(
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
  }
}

final updateBankAccountUseCaseProvider = Provider<UpdateBankAccount>((ref) {
  return UpdateBankAccount(ref.read(accountingRepositoryProvider));
});
