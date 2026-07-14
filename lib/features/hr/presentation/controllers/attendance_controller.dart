import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/entities/employee.dart';
import '../../domain/failures/hr_failure.dart';
import '../../domain/usecases/load_attendance.dart';
import '../../domain/usecases/load_employees.dart';
import '../../domain/usecases/mark_attendance.dart';

/// A month of attendance, optionally scoped to one employee (profile view).
typedef AttendanceQuery = ({int year, int month, String? employeeId});

String _fmt(DateTime d) => d.toIso8601String().substring(0, 10);

final attendanceMonthProvider = FutureProvider.autoDispose
    .family<List<Attendance>, AttendanceQuery>((ref, q) async {
  final from = _fmt(DateTime(q.year, q.month, 1));
  final to = _fmt(DateTime(q.year, q.month + 1, 0)); // day 0 of next = last day
  final (rows, failure) = await ref
      .read(loadAttendanceUseCaseProvider)
      .call(from: from, to: to, employeeId: q.employeeId);
  if (failure != null) throw failure;
  return rows;
});

/// Employees of one branch, for the grid rows.
final branchEmployeesProvider = FutureProvider.autoDispose
    .family<List<Employee>, String>((ref, branchId) async {
  final (list, failure) =
      await ref.read(loadEmployeesUseCaseProvider).call(branchId: branchId);
  if (failure != null) throw failure;
  return list;
});

class AttendanceActions {
  AttendanceActions(this._ref);
  final Ref _ref;

  Future<HrFailure?> mark(
      Map<String, dynamic> data, AttendanceQuery invalidate) async {
    final failure =
        await _ref.read(markAttendanceUseCaseProvider).call(data);
    if (failure != null) return failure;
    _ref.invalidate(attendanceMonthProvider(invalidate));
    return null;
  }
}

final attendanceActionsProvider =
    Provider<AttendanceActions>((ref) => AttendanceActions(ref));
