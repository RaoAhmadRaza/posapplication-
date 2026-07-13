import '../../domain/entities/repair_results.dart';

class RepairCreateResultModel {
  static RepairCreateResult fromJson(Map<String, dynamic> json) {
    return RepairCreateResult(
      repairId: json['repair_id'] as String,
      jobNumber: json['job_number'] as String,
    );
  }
}

class RepairPartResultModel {
  static RepairPartResult fromJson(Map<String, dynamic> json) {
    return RepairPartResult(
      repairPartId: json['repair_part_id'] as String,
      unitCost: double.tryParse(json['unit_cost'].toString()) ?? 0,
      totalCost: double.tryParse(json['total_cost'].toString()) ?? 0,
    );
  }
}

class RepairWarrantyOpenResultModel {
  static RepairWarrantyOpenResult fromJson(Map<String, dynamic> json) {
    return RepairWarrantyOpenResult(
      claimRepairId: json['claim_repair_id'] as String,
      jobNumber: json['job_number'] as String,
    );
  }
}

class RepairWarrantyCloseResultModel {
  static RepairWarrantyCloseResult fromJson(Map<String, dynamic> json) {
    return RepairWarrantyCloseResult(
      repairId: json['repair_id'] as String,
      charged: double.tryParse(json['charged'].toString()) ?? 0,
      warrantyCost: double.tryParse(json['warranty_cost'].toString()) ?? 0,
    );
  }
}

class RepairBulkStatusResultModel {
  static RepairBulkStatusResult fromJson(Map<String, dynamic> json) {
    final failed = (json['failed'] as List? ?? const [])
        .map((e) => RepairBulkFailure(
              repairId: (e as Map)['repair_id'].toString(),
              error: e['error'].toString(),
            ))
        .toList();
    return RepairBulkStatusResult(
      succeeded: (json['succeeded'] as num?)?.toInt() ?? 0,
      failed: failed,
    );
  }
}

class RepairCloseResultModel {
  static RepairCloseResult fromJson(Map<String, dynamic> json) {
    return RepairCloseResult(
      repairId: json['repair_id'] as String,
      invoiceId: json['invoice_id'] as String,
      invoiceNumber: json['invoice_number'] as String,
      grandTotal: double.tryParse(json['grand_total'].toString()) ?? 0,
    );
  }
}
