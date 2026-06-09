import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../repositories/auth_repository.dart';

class SetNewPassword {
  final AuthRepository _repo;
  SetNewPassword(this._repo);

  Future<AuthFailure?> call(String newPassword) async {
    return _repo.setNewPassword(newPassword);
  }
}

final setNewPasswordUseCaseProvider = Provider<SetNewPassword>((ref) {
  return SetNewPassword(ref.read(authRepositoryProvider));
});
