import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/attendance.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/leave.dart';
import '../../domain/entities/payroll.dart';
import '../../domain/entities/salary_advance.dart';
import '../../domain/entities/shift.dart';
import '../../domain/failures/hr_failure.dart';
import '../../domain/repositories/hr_repository.dart';
import '../datasources/hr_remote_datasource.dart';
import '../models/attendance_model.dart';
import '../models/employee_model.dart';
import '../models/leave_model.dart';
import '../models/payroll_item_model.dart';
import '../models/payroll_run_model.dart';
import '../models/salary_advance_model.dart';
import '../models/shift_model.dart';

final hrRepositoryProvider = Provider<HrRepository>((ref) {
  return HrRepositoryImpl(ref.read(hrRemoteDataSourceProvider));
});

class HrRepositoryImpl implements HrRepository {
  final HrRemoteDataSource _ds;

  HrRepositoryImpl(this._ds);

  HrFailure _mapError(Object e) {
    if (e is PostgrestException) {
      final msg = e.message.toLowerCase();
      final code = e.code;
      if (msg.contains('err_permission_denied') || code == '42501') {
        return HrPermissionDeniedFailure();
      }
      if (msg.contains('err_code_taken')) return HrCodeTakenFailure();
      if (msg.contains('err_edit_reason_required')) {
        return HrEditReasonRequiredFailure();
      }
      if (msg.contains('err_leave_not_pending')) {
        return HrLeaveNotPendingFailure();
      }
      if (msg.contains('err_run_not_draft')) return HrRunNotDraftFailure();
      if (msg.contains('err_run_not_calculated')) {
        return HrRunNotCalculatedFailure();
      }
      if (msg.contains('err_run_not_approved')) return HrRunNotApprovedFailure();
      if (msg.contains('err_period_exists')) return HrPeriodExistsFailure();
      if (msg.contains('err_negative_net')) return HrNegativeNetFailure();
      if (msg.contains('err_emp_not_found') ||
          msg.contains('_not_found') ||
          code == 'PGRST116' ||
          code == 'P0002') {
        return HrEmpNotFoundFailure();
      }
    }
    if (e is AuthException) return HrPermissionDeniedFailure();
    if (e is SocketException || e is TimeoutException) {
      return HrUnknownFailure('Network error. Please check your connection.');
    }
    return HrUnknownFailure(e.toString());
  }

  @override
  Future<(List<Employee>, HrFailure?)> loadEmployees({
    String? branchId,
    EmployeeStatus? status,
    String? department,
    String? query,
  }) async {
    try {
      final rows = await _ds.loadEmployees(
        branchId: branchId,
        status: status == null ? null : EmployeeModel.statusToDb(status),
        department: department,
        query: query,
      );
      return (rows.map(EmployeeModel.fromJson).toList(), null);
    } catch (e) {
      return (<Employee>[], _mapError(e));
    }
  }

  @override
  Future<(Employee?, HrFailure?)> loadEmployee(String id) async {
    try {
      final row = await _ds.loadEmployee(id);
      return (EmployeeModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<(List<Shift>, HrFailure?)> loadShifts() async {
    try {
      final rows = await _ds.loadShifts();
      return (rows.map(ShiftModel.fromJson).toList(), null);
    } catch (e) {
      return (<Shift>[], _mapError(e));
    }
  }

  @override
  Future<(String?, HrFailure?)> createEmployee(
      Map<String, dynamic> data) async {
    try {
      final row = await _ds.createEmployee(data);
      return (row['employee_id'] as String?, null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<HrFailure?> updateEmployee(Map<String, dynamic> data) async {
    try {
      await _ds.updateEmployee(data);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<HrFailure?> terminateEmployee({
    required String employeeId,
    required EmployeeStatus status,
    DateTime? terminationDate,
    String? notes,
  }) async {
    try {
      await _ds.terminateEmployee(
        employeeId: employeeId,
        status: EmployeeModel.statusToDb(status),
        terminationDate: terminationDate,
        notes: notes,
      );
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<HrFailure?> upsertShift(Map<String, dynamic> data) async {
    try {
      await _ds.upsertShift(data);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<(List<Attendance>, HrFailure?)> loadAttendance({
    required String from,
    required String to,
    String? employeeId,
  }) async {
    try {
      final rows =
          await _ds.loadAttendance(from: from, to: to, employeeId: employeeId);
      return (rows.map(AttendanceModel.fromJson).toList(), null);
    } catch (e) {
      return (<Attendance>[], _mapError(e));
    }
  }

  @override
  Future<(List<Leave>, HrFailure?)> loadLeaves({
    String? employeeId,
    LeaveStatus? status,
  }) async {
    try {
      final rows = await _ds.loadLeaves(
        employeeId: employeeId,
        status: status == null ? null : LeaveModel.statusToDb(status),
      );
      return (rows.map(LeaveModel.fromJson).toList(), null);
    } catch (e) {
      return (<Leave>[], _mapError(e));
    }
  }

  @override
  Future<(Employee?, HrFailure?)> loadMyEmployee() async {
    try {
      final row = await _ds.loadMyEmployee();
      return (row == null ? null : EmployeeModel.fromJson(row), null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<HrFailure?> markAttendance(Map<String, dynamic> data) async {
    try {
      await _ds.markAttendance(data);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<HrFailure?> applyLeave(Map<String, dynamic> data) async {
    try {
      await _ds.applyLeave(data);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<HrFailure?> decideLeave({
    required String leaveId,
    required bool approve,
    String? rejectionReason,
  }) async {
    try {
      await _ds.decideLeave(
        leaveId: leaveId,
        approve: approve,
        rejectionReason: rejectionReason,
      );
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<(List<PayrollRun>, HrFailure?)> loadPayrollRuns() async {
    try {
      final rows = await _ds.loadPayrollRuns();
      return (rows.map(PayrollRunModel.fromJson).toList(), null);
    } catch (e) {
      return (<PayrollRun>[], _mapError(e));
    }
  }

  @override
  Future<(PayrollRun?, List<PayrollItem>, HrFailure?)> loadPayrollRun(
      String id) async {
    try {
      final runRow = await _ds.loadPayrollRun(id);
      final itemRows = await _ds.loadPayrollItems(id);
      return (
        PayrollRunModel.fromJson(runRow),
        itemRows.map(PayrollItemModel.fromJson).toList(),
        null,
      );
    } catch (e) {
      return (null, <PayrollItem>[], _mapError(e));
    }
  }

  @override
  Future<(List<SalaryAdvance>, HrFailure?)> loadEmployeeAdvances(
      String employeeId) async {
    try {
      final rows = await _ds.loadEmployeeAdvances(employeeId);
      return (rows.map(SalaryAdvanceModel.fromJson).toList(), null);
    } catch (e) {
      return (<SalaryAdvance>[], _mapError(e));
    }
  }

  @override
  Future<(String?, HrFailure?)> createPayrollRun(
      Map<String, dynamic> data) async {
    try {
      final row = await _ds.createPayrollRun(data);
      return (row['run_id'] as String?, null);
    } catch (e) {
      return (null, _mapError(e));
    }
  }

  @override
  Future<HrFailure?> calculatePayroll({
    required String runId,
    Map<String, dynamic> allowances = const {},
    Map<String, dynamic> extraDeductions = const {},
  }) async {
    try {
      await _ds.calculatePayroll(
        runId: runId,
        allowances: allowances,
        extraDeductions: extraDeductions,
      );
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<HrFailure?> approvePayrollRun(String runId) async {
    try {
      await _ds.approvePayrollRun(runId);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<HrFailure?> disbursePayrollRun({
    required String runId,
    required String payAccount,
  }) async {
    try {
      await _ds.disbursePayrollRun(runId: runId, payAccount: payAccount);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }

  @override
  Future<HrFailure?> disburseSalaryAdvance(Map<String, dynamic> data) async {
    try {
      await _ds.disburseSalaryAdvance(data);
      return null;
    } catch (e) {
      return _mapError(e);
    }
  }
}
