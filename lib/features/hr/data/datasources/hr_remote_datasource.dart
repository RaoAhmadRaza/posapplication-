import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase.dart';

final hrRemoteDataSourceProvider = Provider<HrRemoteDataSource>((ref) {
  return HrRemoteDataSource(supabase);
});

class HrRemoteDataSource {
  final SupabaseClient _client;

  HrRemoteDataSource(this._client);

  // All mutations run through RPCs that set tenant/audit ids server-side.

  static const _empCols = 'id, tenant_id, branch_id, user_id, employee_code,'
      ' name, cnic, phone, email, address, designation, department,'
      ' joining_date, termination_date, salary_type, base_salary, bank_name,'
      ' bank_account_number, emergency_contact, emergency_phone, status, notes,'
      ' branches(name)';

  static const _shiftCols = 'id, tenant_id, name, start_time, end_time,'
      ' grace_minutes, break_minutes, is_active';

  static const _attendanceCols = 'id, tenant_id, employee_id, shift_id, date,'
      ' check_in, check_out, status, overtime_hours, late_minutes, notes';

  static const _leaveCols = 'id, tenant_id, employee_id, type, from_date,'
      ' to_date, days, reason, status, rejection_reason, employees(name)';

  static const _runCols = 'id, tenant_id, branch_id, period, period_start,'
      ' period_end, status, total_gross, total_deductions, total_net,'
      ' employee_count, journal_entry_id';

  static const _itemCols = 'id, run_id, employee_id, basic, allowances_json,'
      ' deductions_json, overtime_hours, overtime_amount, gross_salary,'
      ' total_deductions, net_salary, status, employees(name)';

  static const _advanceCols = 'id, tenant_id, employee_id, amount, balance,'
      ' recovery_amount, disbursed_at, fully_recovered_at, journal_entry_id,'
      ' notes';

  Future<List<Map<String, dynamic>>> loadEmployees({
    String? branchId,
    String? status,
    String? department,
    String? query,
  }) async {
    var q = _client
        .from('employees')
        .select(_empCols)
        .isFilter('deleted_at', null);
    if (branchId != null) q = q.eq('branch_id', branchId);
    if (status != null) q = q.eq('status', status);
    if (department != null) q = q.eq('department', department);
    final term = query?.trim();
    if (term != null && term.isNotEmpty) {
      q = q.or('name.ilike.%$term%,employee_code.ilike.%$term%');
    }
    return q.order('name');
  }

  Future<Map<String, dynamic>> loadEmployee(String id) async {
    return _client.from('employees').select(_empCols).eq('id', id).single();
  }

  Future<List<Map<String, dynamic>>> loadShifts() async {
    return _client
        .from('shifts')
        .select(_shiftCols)
        .isFilter('deleted_at', null)
        .order('name');
  }

  Future<Map<String, dynamic>> createEmployee(Map<String, dynamic> data) async {
    final result = await _client.rpc('create_employee', params: {
      'p_branch_id': data['p_branch_id'],
      'p_employee_code': data['p_employee_code'],
      'p_name': data['p_name'],
      'p_cnic': data['p_cnic'],
      'p_phone': data['p_phone'],
      'p_email': data['p_email'],
      'p_address': data['p_address'],
      'p_designation': data['p_designation'],
      'p_department': data['p_department'],
      'p_joining_date': data['p_joining_date'],
      'p_salary_type': data['p_salary_type'],
      'p_base_salary': data['p_base_salary'],
      'p_bank_name': data['p_bank_name'],
      'p_bank_account_number': data['p_bank_account_number'],
      'p_user_id': data['p_user_id'],
      'p_notes': data['p_notes'],
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateEmployee(Map<String, dynamic> data) async {
    final result = await _client.rpc('update_employee', params: {
      'p_employee_id': data['p_employee_id'],
      'p_name': data['p_name'],
      'p_phone': data['p_phone'],
      'p_email': data['p_email'],
      'p_address': data['p_address'],
      'p_designation': data['p_designation'],
      'p_department': data['p_department'],
      'p_salary_type': data['p_salary_type'],
      'p_base_salary': data['p_base_salary'],
      'p_bank_name': data['p_bank_name'],
      'p_bank_account_number': data['p_bank_account_number'],
      'p_status': data['p_status'],
      'p_notes': data['p_notes'],
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> terminateEmployee({
    required String employeeId,
    required String status,
    DateTime? terminationDate,
    String? notes,
  }) async {
    final result = await _client.rpc('terminate_employee', params: {
      'p_employee_id': employeeId,
      'p_termination_date':
          terminationDate?.toIso8601String().substring(0, 10),
      'p_status': status,
      'p_notes': notes,
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> upsertShift(Map<String, dynamic> data) async {
    final result = await _client.rpc('upsert_shift', params: {
      'p_id': data['p_id'],
      'p_name': data['p_name'],
      'p_start': data['p_start'],
      'p_end': data['p_end'],
      'p_grace': data['p_grace'],
      'p_break': data['p_break'],
      'p_active': data['p_active'],
    });
    return result as Map<String, dynamic>;
  }

  /// Attendance in [from, to] (inclusive, 'YYYY-MM-DD'). Tenant-scoped by RLS;
  /// optional single-employee filter for the profile view.
  Future<List<Map<String, dynamic>>> loadAttendance({
    required String from,
    required String to,
    String? employeeId,
  }) async {
    var q = _client
        .from('attendance')
        .select(_attendanceCols)
        .gte('date', from)
        .lte('date', to);
    if (employeeId != null) q = q.eq('employee_id', employeeId);
    return q.order('date');
  }

  Future<List<Map<String, dynamic>>> loadLeaves({
    String? employeeId,
    String? status,
  }) async {
    var q = _client.from('leaves').select(_leaveCols);
    if (employeeId != null) q = q.eq('employee_id', employeeId);
    if (status != null) q = q.eq('status', status);
    return q.order('from_date', ascending: false);
  }

  /// The employee row linked to the signed-in user (for self clock-in/out).
  Future<Map<String, dynamic>?> loadMyEmployee() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    return _client
        .from('employees')
        .select(_empCols)
        .eq('user_id', uid)
        .isFilter('deleted_at', null)
        .maybeSingle();
  }

  Future<Map<String, dynamic>> markAttendance(Map<String, dynamic> data) async {
    final result = await _client.rpc('mark_attendance', params: {
      'p_employee_id': data['p_employee_id'],
      'p_date': data['p_date'],
      'p_shift_id': data['p_shift_id'],
      'p_check_in': data['p_check_in'],
      'p_check_out': data['p_check_out'],
      'p_status': data['p_status'],
      'p_overtime_hours': data['p_overtime_hours'],
      'p_source': data['p_source'],
      'p_notes': data['p_notes'],
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> applyLeave(Map<String, dynamic> data) async {
    final result = await _client.rpc('apply_leave', params: {
      'p_employee_id': data['p_employee_id'],
      'p_type': data['p_type'],
      'p_from': data['p_from'],
      'p_to': data['p_to'],
      'p_days': data['p_days'],
      'p_reason': data['p_reason'],
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> decideLeave({
    required String leaveId,
    required bool approve,
    String? rejectionReason,
  }) async {
    final result = await _client.rpc('decide_leave', params: {
      'p_leave_id': leaveId,
      'p_approve': approve,
      'p_rejection_reason': rejectionReason,
    });
    return result as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> loadPayrollRuns() async {
    return _client
        .from('payroll_runs')
        .select(_runCols)
        .order('period_start', ascending: false);
  }

  Future<Map<String, dynamic>> loadPayrollRun(String id) async {
    return _client.from('payroll_runs').select(_runCols).eq('id', id).single();
  }

  Future<List<Map<String, dynamic>>> loadPayrollItems(String runId) async {
    return _client
        .from('payroll_items')
        .select(_itemCols)
        .eq('run_id', runId)
        .order('net_salary', ascending: false);
  }

  /// All advances for one employee (most recent first).
  Future<List<Map<String, dynamic>>> loadEmployeeAdvances(
      String employeeId) async {
    return _client
        .from('salary_advances')
        .select(_advanceCols)
        .eq('employee_id', employeeId)
        .order('disbursed_at', ascending: false);
  }

  Future<Map<String, dynamic>> createPayrollRun(
      Map<String, dynamic> data) async {
    final result = await _client.rpc('create_payroll_run', params: {
      'p_branch_id': data['p_branch_id'],
      'p_period': data['p_period'],
      'p_start': data['p_start'],
      'p_end': data['p_end'],
      'p_notes': data['p_notes'],
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> calculatePayroll({
    required String runId,
    Map<String, dynamic> allowances = const {},
    Map<String, dynamic> extraDeductions = const {},
  }) async {
    final result = await _client.rpc('calculate_payroll', params: {
      'p_run_id': runId,
      'p_allowances': allowances,
      'p_extra_deductions': extraDeductions,
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> approvePayrollRun(String runId) async {
    final result = await _client
        .rpc('approve_payroll_run', params: {'p_run_id': runId});
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> disbursePayrollRun({
    required String runId,
    required String payAccount,
  }) async {
    final result = await _client.rpc('disburse_payroll_run', params: {
      'p_run_id': runId,
      'p_pay_account': payAccount,
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> disburseSalaryAdvance(
      Map<String, dynamic> data) async {
    final result = await _client.rpc('disburse_salary_advance', params: {
      'p_employee_id': data['p_employee_id'],
      'p_amount': data['p_amount'],
      'p_recovery_amount': data['p_recovery_amount'],
      'p_pay_account': data['p_pay_account'],
      'p_notes': data['p_notes'],
    });
    return result as Map<String, dynamic>;
  }
}
