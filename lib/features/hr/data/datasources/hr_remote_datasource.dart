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
}
