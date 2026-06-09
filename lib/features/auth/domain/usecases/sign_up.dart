import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

class SignUp {
  final AuthRepository _repo;
  SignUp(this._repo);

  Future<(SignUpResult, AuthFailure?)> call({
    required String email,
    required String password,
    String? fullName,
    String? businessName,
  }) async {
    return _repo.signUp(
      email: email,
      password: password,
      fullName: fullName,
      businessName: businessName,
    );
  }
}

final signUpUseCaseProvider = Provider<SignUp>((ref) {
  return SignUp(ref.read(authRepositoryProvider));
});
