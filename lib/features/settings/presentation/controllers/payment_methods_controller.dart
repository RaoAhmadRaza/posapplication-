import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/bank_account_ref.dart';
import '../../domain/entities/payment_method_config.dart';
import '../../domain/failures/settings_failure.dart';
import '../../domain/usecases/settings_usecases.dart';

/// Bank accounts available to link (drives the GL split). Read-only list.
final bankAccountsProvider =
    FutureProvider<List<BankAccountRef>>((ref) async {
  final (banks, failure) = await ref.read(loadBankAccountsUseCaseProvider)();
  if (failure != null) throw failure;
  return banks;
});

final paymentMethodsProvider =
    AsyncNotifierProvider<PaymentMethodsController, List<PaymentMethodConfig>>(
  PaymentMethodsController.new,
);

class PaymentMethodsController
    extends AsyncNotifier<List<PaymentMethodConfig>> {
  @override
  Future<List<PaymentMethodConfig>> build() async {
    final (methods, failure) =
        await ref.read(loadPaymentMethodsUseCaseProvider)();
    if (failure != null) throw failure;
    return methods;
  }

  Future<SettingsFailure?> _reloadAfter(Future<SettingsFailure?> op) async {
    final failure = await op;
    if (failure != null) return failure;
    ref.invalidateSelf();
    await future;
    return null;
  }

  Future<SettingsFailure?> create({
    required String code,
    required String name,
    required bool requiresReference,
    required int sortOrder,
  }) =>
      _reloadAfter(ref.read(createPaymentMethodUseCaseProvider)(
        code: code,
        name: name,
        requiresReference: requiresReference,
        sortOrder: sortOrder,
      ));

  Future<SettingsFailure?> edit(
    String id, {
    String? name,
    bool? isActive,
    bool? requiresReference,
    int? sortOrder,
  }) =>
      _reloadAfter(ref.read(updatePaymentMethodUseCaseProvider)(
        id,
        name: name,
        isActive: isActive,
        requiresReference: requiresReference,
        sortOrder: sortOrder,
      ));

  /// Link (or unlink, when bankAccountId is null) a bank account — this is what
  /// activates the GL split: a linked method resolves to the bank's GL account.
  Future<SettingsFailure?> linkBankAccount(String id, String? bankAccountId) =>
      _reloadAfter(ref.read(updatePaymentMethodUseCaseProvider)(
        id,
        bankAccountId: bankAccountId,
        clearBankAccount: bankAccountId == null,
      ));

  Future<SettingsFailure?> remove(String id) =>
      _reloadAfter(ref.read(deletePaymentMethodUseCaseProvider)(id));
}
