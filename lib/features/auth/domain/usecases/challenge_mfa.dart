import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/mfa_repository_impl.dart';
import '../repositories/mfa_repository.dart';

class ChallengeMfa {
  final MfaRepository _repo;
  ChallengeMfa(this._repo);

  Future<(String?, AuthFailure?)> call(String factorId) =>
      _repo.challenge(factorId);
}

final challengeMfaUseCaseProvider = Provider<ChallengeMfa>((ref) {
  return ChallengeMfa(ref.read(mfaRepositoryProvider));
});
