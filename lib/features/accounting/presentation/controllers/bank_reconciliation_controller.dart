import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/bank_reconciliation.dart';
import '../../domain/entities/reconciliation_result.dart';
import '../../domain/failures/accounting_failure.dart';
import '../../domain/usecases/complete_bank_reconciliation.dart';
import '../../domain/usecases/create_bank_reconciliation.dart';
import '../../domain/usecases/load_bank_reconciliations.dart';

final bankReconciliationsProvider = FutureProvider.autoDispose
    .family<List<BankReconciliation>, String>((ref, bankAccountId) async {
      final (items, failure) = await ref
          .read(loadBankReconciliationsUseCaseProvider)
          .call(bankAccountId);
      if (failure != null) throw failure;
      return items;
    });

final bankReconciliationControllerProvider =
    NotifierProvider<BankReconciliationController, void>(
      BankReconciliationController.new,
    );

class BankReconciliationController extends Notifier<void> {
  @override
  void build() {}

  Future<(ReconciliationResult?, AccountingFailure?)> createReconciliation({
    required String bankAccountId,
    required DateTime statementDate,
    required double statementBalance,
    String? notes,
  }) async {
    final (result, failure) = await ref
        .read(createBankReconciliationUseCaseProvider)
        .call(
          bankAccountId: bankAccountId,
          statementDate: statementDate,
          statementBalance: statementBalance,
          notes: notes,
        );
    if (failure == null) {
      ref.invalidate(bankReconciliationsProvider(bankAccountId));
    }
    return (result, failure);
  }

  Future<AccountingFailure?> completeReconciliation({
    required String bankAccountId,
    required String reconciliationId,
    required double reconciledBalance,
    String? notes,
  }) async {
    final (_, failure) = await ref
        .read(completeBankReconciliationUseCaseProvider)
        .call(
          reconciliationId: reconciliationId,
          reconciledBalance: reconciledBalance,
          notes: notes,
        );
    if (failure != null) return failure;
    ref.invalidate(bankReconciliationsProvider(bankAccountId));
    return null;
  }
}
