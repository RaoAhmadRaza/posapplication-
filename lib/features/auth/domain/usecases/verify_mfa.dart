import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/mfa_repository_impl.dart';
import '../repositories/mfa_repository.dart';

class VerifyMfa {
  final MfaRepository _repo;
  VerifyMfa(this._repo);

  Future<AuthFailure?> call({
    required String factorId,
    required String challengeId,
    required String code,
  }) async {
    return _repo.verify(
      factorId: factorId,
      challengeId: challengeId,
      code: code,
    );
  }
}

final verifyMfaUseCaseProvider = Provider<VerifyMfa>((ref) {
  return VerifyMfa(ref.read(mfaRepositoryProvider));
});
