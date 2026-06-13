import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../../../core/services/audit_service.dart';
import '../../domain/usecases/set_new_password.dart';

final resetControllerProvider =
    NotifierProvider<ResetController, AsyncValue<void>>(
  ResetController.new,
);

class ResetController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    ref.onDispose(() {
      RecoveryState.instance.reset();
    });
    return const AsyncValue.data(null);
  }

  Future<AuthFailure?> setNewPassword(String newPassword) async {
    state = const AsyncValue.loading();
    final failure =
        await ref.read(setNewPasswordUseCaseProvider).call(newPassword);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
    } else {
      AuditService.instance.log(action: 'PASSWORD_RESET', entity: 'auth');
      RecoveryState.instance.reset();
      state = const AsyncValue.data(null);
    }
    return failure;
  }

  void clear() => state = const AsyncValue.data(null);
}
