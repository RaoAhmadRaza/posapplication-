import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../domain/usecases/set_new_password.dart';

final resetControllerProvider =
    NotifierProvider<ResetController, AsyncValue<void>>(
  ResetController.new,
);

class ResetController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    ref.onDispose(() {
      RecoveryState.instance.isRecovering = false;
    });
    return const AsyncValue.data(null);
  }

  Future<void> setNewPassword(String newPassword) async {
    state = const AsyncValue.loading();
    final failure =
        await ref.read(setNewPasswordUseCaseProvider).call(newPassword);
    if (failure != null) {
      RecoveryState.instance.isRecovering = false;
      state = AsyncValue.error(failure, StackTrace.current);
    } else {
      RecoveryState.instance.isRecovering = false;
      state = const AsyncValue.data(null);
    }
  }

  void clear() => state = const AsyncValue.data(null);
}
