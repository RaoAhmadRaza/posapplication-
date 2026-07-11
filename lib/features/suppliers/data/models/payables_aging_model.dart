import '../../domain/entities/payables_aging.dart';

class PayablesAgingModel {
  static PayablesAging fromJson(Map<String, dynamic> json) {
    final bySupplier = (json['by_supplier'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_supplier)
        .toList();
    return PayablesAging(
      totalPayable: _num(json['total_payable']),
      current: _num(json['bucket_current']),
      bucket1To30: _num(json['bucket_1_30']),
      bucket31To60: _num(json['bucket_31_60']),
      bucket61To90: _num(json['bucket_61_90']),
      bucket90Plus: _num(json['bucket_90_plus']),
      bySupplier: bySupplier,
    );
  }

  static PayablesAgingSupplier _supplier(Map<String, dynamic> j) {
    return PayablesAgingSupplier(
      supplierId: j['supplier_id'] as String? ?? '',
      supplierName: j['supplier_name'] as String? ?? '',
      balance: _num(j['balance']),
      daysOverdue: (j['days_overdue'] as num?)?.toInt() ?? 0,
    );
  }

  static double _num(dynamic v) => double.tryParse(v.toString()) ?? 0;
}
