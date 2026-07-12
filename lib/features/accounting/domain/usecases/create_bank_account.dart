import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/bank_account.dart';
import '../failures/accounting_failure.dart';
import '../repositories/accounting_repository.dart';
import '../../data/repositories/accounting_repository_impl.dart';

class CreateBankAccount {
  final AccountingRepository _repo;
  CreateBankAccount(this._repo);

  Future<(BankAccount?, AccountingFailure?)> call({
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
    return _repo.createBankAccount(
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

final createBankAccountUseCaseProvider = Provider<CreateBankAccount>((ref) {
  return CreateBankAccount(ref.read(accountingRepositoryProvider));
});
