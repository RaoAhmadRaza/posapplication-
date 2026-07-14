import '../entities/attendance.dart';
import '../entities/employee.dart';
import '../entities/leave.dart';
import '../entities/payroll.dart';
import '../entities/salary_advance.dart';
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

  /// Attendance in [from, to] (inclusive), optionally one employee.
  Future<(List<Attendance>, HrFailure?)> loadAttendance({
    required String from,
    required String to,
    String? employeeId,
  });

  Future<(List<Leave>, HrFailure?)> loadLeaves({
    String? employeeId,
    LeaveStatus? status,
  });

  /// Employee row linked to the signed-in user, if any.
  Future<(Employee?, HrFailure?)> loadMyEmployee();

  Future<HrFailure?> markAttendance(Map<String, dynamic> data);

  Future<HrFailure?> applyLeave(Map<String, dynamic> data);

  Future<HrFailure?> decideLeave({
    required String leaveId,
    required bool approve,
    String? rejectionReason,
  });

  Future<(List<PayrollRun>, HrFailure?)> loadPayrollRuns();

  /// One run plus its items (items empty until calculated).
  Future<(PayrollRun?, List<PayrollItem>, HrFailure?)> loadPayrollRun(
      String id);

  Future<(List<SalaryAdvance>, HrFailure?)> loadEmployeeAdvances(
      String employeeId);

  /// Returns the new run id on success.
  Future<(String?, HrFailure?)> createPayrollRun(Map<String, dynamic> data);

  Future<HrFailure?> calculatePayroll({
    required String runId,
    Map<String, dynamic> allowances = const {},
    Map<String, dynamic> extraDeductions = const {},
  });

  Future<HrFailure?> approvePayrollRun(String runId);

  Future<HrFailure?> disbursePayrollRun({
    required String runId,
    required String payAccount,
  });

  Future<HrFailure?> disburseSalaryAdvance(Map<String, dynamic> data);
}
