import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../../../core/services/audit_service.dart';
import '../../../../core/services/login_throttle_service.dart';
import '../../domain/usecases/sign_in.dart';

final signInControllerProvider =
    NotifierProvider<SignInController, AsyncValue<void>>(
  SignInController.new,
);

class SignInController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    final (result, failure) = await ref
        .read(signInUseCaseProvider)
        .call(email: email, password: password);

    if (failure != null) {
      if (failure is InvalidCredentialsFailure) {
        try {
          await LoginThrottleService.instance.recordFailure(email);
        } on AccountLockedException catch (e) {
          state = AsyncValue.error(
            AccountLockedFailure(e.lockedUntil),
            StackTrace.current,
          );
          return;
        }
      }
      state = AsyncValue.error(failure, StackTrace.current);
      return;
    }

    if (result.emailNeedingConfirmation != null) {
      state = AsyncValue.error(
        EmailNotConfirmedFailure(result.emailNeedingConfirmation!),
        StackTrace.current,
      );
      return;
    }

    LoginThrottleService.instance.reset(email);
    AuditService.instance.log(action: 'LOGIN', entity: 'auth');
    state = const AsyncValue.data(null);
  }

  void clear() => state = const AsyncValue.data(null);
}
