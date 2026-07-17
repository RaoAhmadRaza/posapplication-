import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/audit_service.dart';
import '../../domain/usecases/sign_up.dart';
import '../../domain/repositories/auth_repository.dart';

final signUpControllerProvider =
    NotifierProvider<SignUpController, AsyncValue<SignUpResult>>(
  SignUpController.new,
);

class SignUpController extends Notifier<AsyncValue<SignUpResult>> {
  @override
  AsyncValue<SignUpResult> build() =>
      AsyncValue.data(SignUpResult.success());

  Future<String?> signUp({
    required String email,
    required String password,
    String? fullName,
    String? businessName,
    bool demoMode = false,
  }) async {
    state = const AsyncValue.loading();
    final (result, failure) = await ref.read(signUpUseCaseProvider).call(
          email: email,
          password: password,
          fullName: fullName,
          businessName: businessName,
          demoMode: demoMode,
        );

    if (failure != null) {
      state = AsyncValue.error(failure, StackTrace.current);
      return null;
    }

    AuditService.instance.log(action: 'SIGNUP', entity: 'auth');
    state = AsyncValue.data(result);
    return result.emailNeedingConfirmation;
  }

  void clear() => state = AsyncValue.data(SignUpResult.success());
}
