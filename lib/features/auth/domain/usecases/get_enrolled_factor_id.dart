import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/mfa_repository_impl.dart';
import '../repositories/mfa_repository.dart';

class GetEnrolledFactorId {
  final MfaRepository _repo;
  GetEnrolledFactorId(this._repo);

  Future<(String?, AuthFailure?)> call() => _repo.getEnrolledFactorId();
}

final getEnrolledFactorIdUseCaseProvider = Provider<GetEnrolledFactorId>((ref) {
  return GetEnrolledFactorId(ref.read(mfaRepositoryProvider));
});
