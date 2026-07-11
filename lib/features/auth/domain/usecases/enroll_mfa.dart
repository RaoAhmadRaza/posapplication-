import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/datasources/mfa_remote_datasource.dart';
import '../../data/repositories/mfa_repository_impl.dart';
import '../repositories/mfa_repository.dart';

class EnrollMfa {
  final MfaRepository _repo;
  EnrollMfa(this._repo);

  Future<(MfaEnrollResult?, AuthFailure?)> call() => _repo.enroll();
}

final enrollMfaUseCaseProvider = Provider<EnrollMfa>((ref) {
  return EnrollMfa(ref.read(mfaRepositoryProvider));
});
