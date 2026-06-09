import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

class RequestPasswordReset {
  final AuthRepository _repo;
  RequestPasswordReset(this._repo);

  Future<AuthFailure?> call(String email) async {
    return _repo.requestPasswordReset(email);
  }
}

final requestPasswordResetUseCaseProvider = Provider<RequestPasswordReset>((ref) {
  return RequestPasswordReset(ref.read(authRepositoryProvider));
});
