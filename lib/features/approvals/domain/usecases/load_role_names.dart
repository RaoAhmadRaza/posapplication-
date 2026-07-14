import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../failures/approval_failure.dart';
import '../repositories/approvals_repository.dart';
import '../../data/repositories/approvals_repository_impl.dart';

class LoadRoleNames {
  final ApprovalsRepository _repo;
  LoadRoleNames(this._repo);

  Future<(List<String>, ApprovalFailure?)> call() => _repo.loadRoleNames();
}

final loadRoleNamesUseCaseProvider = Provider<LoadRoleNames>((ref) {
  return LoadRoleNames(ref.read(approvalsRepositoryProvider));
});
