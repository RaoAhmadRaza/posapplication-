import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/leave.dart';
import '../../domain/failures/hr_failure.dart';
import '../../domain/usecases/apply_leave.dart';
import '../../domain/usecases/decide_leave.dart';
import '../../domain/usecases/load_leaves.dart';
import '../../domain/usecases/load_my_employee.dart';

typedef LeavesQuery = ({String? employeeId, LeaveStatus? status});

final leavesProvider =
    FutureProvider.autoDispose.family<List<Leave>, LeavesQuery>((ref, q) async {
  final (rows, failure) = await ref
      .read(loadLeavesUseCaseProvider)
      .call(employeeId: q.employeeId, status: q.status);
  if (failure != null) throw failure;
  return rows;
});

/// Employee row linked to the signed-in user (self-service leave/clock).
final myEmployeeProvider =
    FutureProvider.autoDispose<Employee?>((ref) async {
  final (employee, failure) =
      await ref.read(loadMyEmployeeUseCaseProvider).call();
  if (failure != null) throw failure;
  return employee;
});

class LeaveActions {
  LeaveActions(this._ref);
  final Ref _ref;

  Future<HrFailure?> apply(
      Map<String, dynamic> data, LeavesQuery invalidate) async {
    final failure = await _ref.read(applyLeaveUseCaseProvider).call(data);
    if (failure != null) return failure;
    _ref.invalidate(leavesProvider(invalidate));
    return null;
  }

  Future<HrFailure?> decide({
    required String leaveId,
    required bool approve,
    String? rejectionReason,
    required LeavesQuery invalidate,
  }) async {
    final failure = await _ref.read(decideLeaveUseCaseProvider).call(
          leaveId: leaveId,
          approve: approve,
          rejectionReason: rejectionReason,
        );
    if (failure != null) return failure;
    _ref.invalidate(leavesProvider(invalidate));
    return null;
  }
}

final leaveActionsProvider =
    Provider<LeaveActions>((ref) => LeaveActions(ref));
