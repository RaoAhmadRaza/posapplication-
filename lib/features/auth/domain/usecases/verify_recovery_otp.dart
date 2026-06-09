import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

class VerifyRecoveryOtp {
  final AuthRepository _repo;
  VerifyRecoveryOtp(this._repo);

  Future<AuthFailure?> call({
    required String email,
    required String code,
  }) async {
    return _repo.verifyRecoveryOtp(email: email, code: code);
  }
}

final verifyRecoveryOtpUseCaseProvider = Provider<VerifyRecoveryOtp>((ref) {
  return VerifyRecoveryOtp(ref.read(authRepositoryProvider));
});
