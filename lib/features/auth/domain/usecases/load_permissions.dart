import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../entities/permission.dart';
import '../repositories/auth_repository.dart';

class LoadPermissions {
  final AuthRepository _repo;
  LoadPermissions(this._repo);

  Future<(List<Permission>, AuthFailure?)> call(String roleId) async {
    return _repo.loadPermissions(roleId);
  }
}

final loadPermissionsUseCaseProvider = Provider<LoadPermissions>((ref) {
  return LoadPermissions(ref.read(authRepositoryProvider));
});
