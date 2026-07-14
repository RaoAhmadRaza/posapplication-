import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/shift.dart';
import '../../domain/failures/hr_failure.dart';
import '../../domain/repositories/hr_repository.dart';
import '../datasources/hr_remote_datasource.dart';
import '../models/employee_model.dart';
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
}
