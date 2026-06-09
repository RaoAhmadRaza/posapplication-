import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

class ResendCode {
  final AuthRepository _repo;
  ResendCode(this._repo);

  Future<AuthFailure?> call({
    required String email,
    required bool isRecovery,
  }) async {
    return _repo.resendCode(email: email, isRecovery: isRecovery);
  }
}

final resendCodeUseCaseProvider = Provider<ResendCode>((ref) {
  return ResendCode(ref.read(authRepositoryProvider));
});
