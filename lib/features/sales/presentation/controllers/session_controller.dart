import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/controllers/branch_controller.dart';
import '../../domain/entities/cashier_session.dart';
import '../../domain/failures/sales_failure.dart';
import '../../domain/usecases/open_session.dart';
import '../../domain/usecases/close_session.dart';
import '../../domain/usecases/load_open_session.dart';

final sessionProvider =
    AsyncNotifierProvider<SessionController, CashierSession?>(
  SessionController.new,
);

class SessionController extends AsyncNotifier<CashierSession?> {
  @override
  Future<CashierSession?> build() async {
    final branch = ref.watch(currentBranchProvider);
    if (branch == null) return null;
    final (session, failure) =
        await ref.read(loadOpenSessionUseCaseProvider).call(branch.id);
    if (failure != null) throw failure;
    return session;
  }

  Future<SalesFailure?> open({required String branchId, double openingFloat = 0}) async {
    final (session, failure) = await ref.read(openSessionUseCaseProvider).call(
          branchId: branchId,
          openingFloat: openingFloat,
        );
    if (failure != null) return failure;
    ref.invalidateSelf();
    return null;
  }

  Future<Map<String, dynamic>?> close({
    required String sessionId,
    required double closingFloat,
    String? notes,
  }) async {
    final (result, failure) = await ref.read(closeSessionUseCaseProvider).call(
          sessionId: sessionId,
          closingFloat: closingFloat,
          notes: notes,
        );
    if (failure != null) return null;
    ref.invalidateSelf();
    return result;
  }
}
