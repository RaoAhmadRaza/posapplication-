import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/auth_failure.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../entities/branch.dart';
import '../repositories/auth_repository.dart';

class LoadUserBranches {
  final AuthRepository _repo;
  LoadUserBranches(this._repo);

  Future<(List<Branch>, AuthFailure?)> call(String userId) async {
    return _repo.loadUserBranches(userId);
  }
}

final loadUserBranchesUseCaseProvider = Provider<LoadUserBranches>((ref) {
  return LoadUserBranches(ref.read(authRepositoryProvider));
});
