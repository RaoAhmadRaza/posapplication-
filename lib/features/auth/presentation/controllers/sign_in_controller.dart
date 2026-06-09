import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
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

    state = const AsyncValue.data(null);
  }

  void clear() => state = const AsyncValue.data(null);
}
