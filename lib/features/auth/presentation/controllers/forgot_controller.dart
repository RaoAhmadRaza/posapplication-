import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../domain/usecases/request_password_reset.dart';

final forgotControllerProvider =
    NotifierProvider<ForgotController, AsyncValue<void>>(
  ForgotController.new,
);

class ForgotController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<AuthFailure?> requestReset(String email) async {
    state = const AsyncValue.loading();
    final failure =
        await ref.read(requestPasswordResetUseCaseProvider).call(email);
    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
    } else {
      state = const AsyncValue.data(null);
    }
    return failure;
  }

  void clear() => state = const AsyncValue.data(null);
}
