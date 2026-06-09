import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../entities/auth_profile.dart';
import '../repositories/auth_repository.dart';

class LoadProfile {
  final AuthRepository _repo;
  LoadProfile(this._repo);

  Future<(AuthProfile?, AuthFailure?)> call(String userId) async {
    return _repo.loadProfile(userId);
  }
}

final loadProfileUseCaseProvider = Provider<LoadProfile>((ref) {
  return LoadProfile(ref.read(authRepositoryProvider));
});
