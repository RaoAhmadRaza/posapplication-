import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase.dart';

final repairRemoteDataSourceProvider =
    Provider<RepairRemoteDataSource>((ref) {
  return RepairRemoteDataSource(supabase);
});

class RepairRemoteDataSource {
  final SupabaseClient _client;

  RepairRemoteDataSource(this._client);

  // All mutations run through RPCs that set tenant/audit ids server-side.

  static const _jobCols = 'id, tenant_id, branch_id, customer_id, job_number,'
      ' device_type, device_brand, device_model, serial_no, imei,'
      ' reported_issue, diagnosis, technician_id, status, priority,'
      ' estimated_cost, final_cost, customer_approved, invoice_id,'
      ' warranty_expires_at, received_at, delivered_at,'
      ' customer_signature_url, notes, created_at, customers(name)';

  static const _partCols = 'id, repair_id, product_id, qty, unit_cost,'
      ' total_cost, notes, created_at, products(name)';

  static const _historyCols =
      'id, repair_id, old_status, new_status, changed_by, changed_at, notes';

  Future<List<Map<String, dynamic>>> loadRepairJobs({
    String? status,
    String? technicianId,
  }) async {
    var q = _client
        .from('repair_jobs')
        .select(_jobCols)
        .isFilter('deleted_at', null);
    if (status != null) q = q.eq('status', status);
    if (technicianId != null) q = q.eq('technician_id', technicianId);
    return q.order('created_at', ascending: false);
  }

  /// Delivered + cancelled jobs for the history view (most recent first).
  Future<List<Map<String, dynamic>>> loadClosedRepairJobs() async {
    return _client
        .from('repair_jobs')
        .select(_jobCols)
        .isFilter('deleted_at', null)
        .inFilter('status', ['DELIVERED', 'CANCELLED'])
        .order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>> loadRepairJob(String id) async {
    return _client.from('repair_jobs').select(_jobCols).eq('id', id).single();
  }

  Future<List<Map<String, dynamic>>> loadRepairParts(String repairId) async {
    return _client
        .from('repair_parts')
        .select(_partCols)
        .eq('repair_id', repairId)
        .order('created_at');
  }

  Future<List<Map<String, dynamic>>> loadStatusHistory(String repairId) async {
    return _client
        .from('repair_status_history')
        .select(_historyCols)
        .eq('repair_id', repairId)
        .order('changed_at');
  }

  Future<List<Map<String, dynamic>>> loadTechnicians() async {
    // RLS scopes users to the caller's tenant.
    return _client.from('users').select('id, full_name').order('full_name');
  }

  Future<Map<String, dynamic>> createRepairJob(
      Map<String, dynamic> data) async {
    final result = await _client.rpc('create_repair_job', params: {
      'p_branch_id': data['p_branch_id'],
      'p_customer_id': data['p_customer_id'],
      'p_device_type': data['p_device_type'],
      'p_device_brand': data['p_device_brand'],
      'p_device_model': data['p_device_model'],
      'p_serial_no': data['p_serial_no'],
      'p_imei': data['p_imei'],
      'p_reported_issue': data['p_reported_issue'],
      'p_priority': data['p_priority'],
      'p_estimated_cost': data['p_estimated_cost'],
      'p_signature_url': data['p_signature_url'],
      'p_notes': data['p_notes'],
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> assignTechnician(
      String repairId, String technicianId) async {
    final result = await _client.rpc('assign_technician', params: {
      'p_repair_id': repairId,
      'p_technician_id': technicianId,
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> setDiagnosis({
    required String repairId,
    required String diagnosis,
    double? estimatedCost,
    bool? customerApproved,
  }) async {
    final result = await _client.rpc('set_repair_diagnosis', params: {
      'p_repair_id': repairId,
      'p_diagnosis': diagnosis,
      'p_estimated_cost': estimatedCost,
      'p_customer_approved': customerApproved,
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> changeStatus({
    required String repairId,
    required String newStatus,
    String? notes,
  }) async {
    final result = await _client.rpc('change_repair_status', params: {
      'p_repair_id': repairId,
      'p_new_status': newStatus,
      'p_notes': notes,
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> addPart({
    required String repairId,
    required String productId,
    String? variantId,
    required double qty,
    String? notes,
  }) async {
    final result = await _client.rpc('add_repair_part', params: {
      'p_repair_id': repairId,
      'p_product_id': productId,
      'p_variant_id': variantId,
      'p_qty': qty,
      'p_notes': notes,
    });
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> removePart(String repairPartId) async {
    final result = await _client.rpc('remove_repair_part',
        params: {'p_repair_part_id': repairPartId});
    return result as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> closeJob({
    required String repairId,
    required double labourPrice,
    required double labourTaxPct,
    required Map<String, double> partsMarkup,
    required double paidAmount,
    int? warrantyDays,
    String? signatureUrl,
  }) async {
    final result = await _client.rpc('close_repair_job', params: {
      'p_repair_id': repairId,
      'p_labour_price': labourPrice,
      'p_labour_tax_pct': labourTaxPct,
      'p_parts_markup': partsMarkup,
      'p_paid_amount': paidAmount,
      'p_warranty_days': warrantyDays,
      'p_signature_url': signatureUrl,
    });
    return result as Map<String, dynamic>;
  }

  /// Uploads the signature PNG to the private 'signatures' bucket at
  /// `tenant_id/repair_id.png` (RLS-scoped by the tenant path prefix).
  /// Returns the storage path — stored on the job, signed fresh at view time.
  Future<String> uploadSignature(String repairId, Uint8List bytes) async {
    final tenantId = await _client.rpc('auth_tenant_id') as String;
    final path = '$tenantId/$repairId.png';
    await _client.storage.from('signatures').uploadBinary(
          path,
          bytes,
          fileOptions:
              const FileOptions(contentType: 'image/png', upsert: true),
        );
    return path;
  }

  /// Fresh short-lived (60s) signed URL for a stored signature path. The object
  /// is private — never a public link.
  Future<String> signatureSignedUrl(String path) {
    return _client.storage.from('signatures').createSignedUrl(path, 60);
  }
}
