import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

class VerifyEmailOtp {
  final AuthRepository _repo;
  VerifyEmailOtp(this._repo);

  Future<AuthFailure?> call({
    required String email,
    required String code,
  }) async {
    return _repo.verifyEmailOtp(email: email, code: code);
  }
}

final verifyEmailOtpUseCaseProvider = Provider<VerifyEmailOtp>((ref) {
  return VerifyEmailOtp(ref.read(authRepositoryProvider));
});
