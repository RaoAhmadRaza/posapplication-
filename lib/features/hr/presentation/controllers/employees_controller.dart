import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/employee.dart';
import '../../domain/failures/hr_failure.dart';
import '../../domain/usecases/load_employees.dart';
import '../../domain/usecases/load_employee.dart';
import '../../domain/usecases/create_employee.dart';
import '../../domain/usecases/update_employee.dart';
import '../../domain/usecases/terminate_employee.dart';

final employeesProvider =
    AsyncNotifierProvider<EmployeesController, List<Employee>>(
  EmployeesController.new,
);

class EmployeesController extends AsyncNotifier<List<Employee>> {
  EmployeeStatus? _status;
  String? _department;
  String? _query;

  EmployeeStatus? get statusFilter => _status;
  String? get departmentFilter => _department;
  String? get query => _query;

  @override
  Future<List<Employee>> build() => _load();

  Future<List<Employee>> _load() async {
    final (employees, failure) = await ref.read(loadEmployeesUseCaseProvider).call(
          status: _status,
          department: _department,
          query: _query,
        );
    if (failure != null) throw failure;
    return employees;
  }

  Future<void> setFilters({
    EmployeeStatus? status,
    String? department,
    String? query,
    bool clearStatus = false,
    bool clearDepartment = false,
  }) async {
    if (clearStatus) _status = null;
    if (status != null) _status = status;
    if (clearDepartment) _department = null;
    if (department != null) _department = department;
    _query = query;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  void refresh() => ref.invalidateSelf();

  void _invalidateDetail(String id) =>
      ref.invalidate(employeeDetailProvider(id));

  Future<(String?, HrFailure?)> create(Map<String, dynamic> data) async {
    final (id, failure) =
        await ref.read(createEmployeeUseCaseProvider).call(data);
    if (failure != null) return (null, failure);
    ref.invalidateSelf();
    return (id, null);
  }

  Future<HrFailure?> updateEmployee(
      String id, Map<String, dynamic> data) async {
    final failure = await ref.read(updateEmployeeUseCaseProvider).call(data);
    if (failure != null) return failure;
    ref.invalidateSelf();
    _invalidateDetail(id);
    return null;
  }

  Future<HrFailure?> terminate({
    required String employeeId,
    required EmployeeStatus status,
    DateTime? terminationDate,
    String? notes,
  }) async {
    final failure = await ref.read(terminateEmployeeUseCaseProvider).call(
          employeeId: employeeId,
          status: status,
          terminationDate: terminationDate,
          notes: notes,
        );
    if (failure != null) return failure;
    ref.invalidateSelf();
    _invalidateDetail(employeeId);
    return null;
  }
}

/// One employee's full record, for the profile page. Auto-disposes.
final employeeDetailProvider =
    FutureProvider.autoDispose.family<Employee, String>((ref, id) async {
  final (employee, failure) =
      await ref.read(loadEmployeeUseCaseProvider).call(id);
  if (failure != null) throw failure;
  return employee!;
});
