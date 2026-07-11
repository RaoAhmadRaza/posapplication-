import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/mfa_repository_impl.dart';
import '../repositories/mfa_repository.dart';

class UnenrollMfa {
  final MfaRepository _repo;
  UnenrollMfa(this._repo);

  Future<AuthFailure?> call(String factorId) => _repo.unenroll(factorId);
}

final unenrollMfaUseCaseProvider = Provider<UnenrollMfa>((ref) {
  return UnenrollMfa(ref.read(mfaRepositoryProvider));
});
