import '../../domain/entities/cashier_session.dart';

class CashierSessionModel {
  static CashierSession fromJson(Map<String, dynamic> json) {
    return CashierSession(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      cashierId: json['cashier_id'] as String,
      deviceId: json['device_id'] as String?,
      openingFloat: double.tryParse(json['opening_float'].toString()) ?? 0,
      closingFloat: json['closing_float'] != null
          ? double.tryParse(json['closing_float'].toString())
          : null,
      expectedFloat: json['expected_float'] != null
          ? double.tryParse(json['expected_float'].toString())
          : null,
      cashVariance: json['cash_variance'] != null
          ? double.tryParse(json['cash_variance'].toString())
          : null,
      totalSales: double.tryParse(json['total_sales'].toString()) ?? 0,
      totalReturns: double.tryParse(json['total_returns'].toString()) ?? 0,
      totalTransactions: json['total_transactions'] as int,
      status: _parseStatus(json['status'] as String),
      openedAt: DateTime.parse(json['opened_at'] as String),
      closedAt: json['closed_at'] != null
          ? DateTime.tryParse(json['closed_at'] as String)
          : null,
      closedBy: json['closed_by'] as String?,
      notes: json['notes'] as String?,
    );
  }

  static CashierSessionStatus _parseStatus(String s) {
    return switch (s.toUpperCase()) {
      'OPEN' => CashierSessionStatus.open,
      'CLOSED' => CashierSessionStatus.closed,
      'SUSPENDED' => CashierSessionStatus.suspended,
      _ => CashierSessionStatus.open,
    };
  }
}
