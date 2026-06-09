import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

class SignIn {
  final AuthRepository _repo;
  SignIn(this._repo);

  Future<(SignInResult, AuthFailure?)> call({
    required String email,
    required String password,
  }) async {
    return _repo.signIn(email: email, password: password);
  }
}

final signInUseCaseProvider = Provider<SignIn>((ref) {
  return SignIn(ref.read(authRepositoryProvider));
});
