import '../../domain/entities/receivables_aging.dart';

class ReceivablesAgingModel {
  static ReceivablesAging fromJson(Map<String, dynamic> json) {
    final byCustomer = (json['by_customer'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .map(_customer)
        .toList();
    return ReceivablesAging(
      totalReceivable: _num(json['total_receivable']),
      current: _num(json['bucket_current']),
      bucket1To30: _num(json['bucket_1_30']),
      bucket31To60: _num(json['bucket_31_60']),
      bucket61To90: _num(json['bucket_61_90']),
      bucket90Plus: _num(json['bucket_90_plus']),
      byCustomer: byCustomer,
    );
  }

  static ReceivablesAgingCustomer _customer(Map<String, dynamic> j) {
    return ReceivablesAgingCustomer(
      customerId: j['customer_id'] as String? ?? '',
      customerName: j['customer_name'] as String? ?? '',
      balance: _num(j['balance']),
      daysOverdue: (j['days_overdue'] as num?)?.toInt() ?? 0,
    );
  }

  static double _num(dynamic v) => double.tryParse(v.toString()) ?? 0;
}
