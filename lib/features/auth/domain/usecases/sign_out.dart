import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

class SignOut {
  final AuthRepository _repo;
  SignOut(this._repo);

  Future<AuthFailure?> call() async {
    return _repo.signOut();
  }
}

final signOutUseCaseProvider = Provider<SignOut>((ref) {
  return SignOut(ref.read(authRepositoryProvider));
});
