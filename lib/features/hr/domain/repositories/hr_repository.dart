import '../entities/employee.dart';
import '../entities/shift.dart';
import '../failures/hr_failure.dart';

abstract class HrRepository {
  Future<(List<Employee>, HrFailure?)> loadEmployees({
    String? branchId,
    EmployeeStatus? status,
    String? department,
    String? query,
  });

  Future<(Employee?, HrFailure?)> loadEmployee(String id);

  Future<(List<Shift>, HrFailure?)> loadShifts();

  /// Returns the new employee id on success.
  Future<(String?, HrFailure?)> createEmployee(Map<String, dynamic> data);

  Future<HrFailure?> updateEmployee(Map<String, dynamic> data);

  Future<HrFailure?> terminateEmployee({
    required String employeeId,
    required EmployeeStatus status,
    DateTime? terminationDate,
    String? notes,
  });

  /// Insert (id == null) or update a shift.
  Future<HrFailure?> upsertShift(Map<String, dynamic> data);
}
