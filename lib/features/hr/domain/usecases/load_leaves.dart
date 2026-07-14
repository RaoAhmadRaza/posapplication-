import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../entities/leave.dart';
import '../failures/hr_failure.dart';
import '../repositories/hr_repository.dart';
import '../../data/repositories/hr_repository_impl.dart';

class LoadLeaves {
  final HrRepository _repo;
  LoadLeaves(this._repo);

  Future<(List<Leave>, HrFailure?)> call(
      {String? employeeId, LeaveStatus? status}) {
    return _repo.loadLeaves(employeeId: employeeId, status: status);
  }
}

final loadLeavesUseCaseProvider = Provider<LoadLeaves>((ref) {
  return LoadLeaves(ref.read(hrRepositoryProvider));
});
