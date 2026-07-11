enum CashierSessionStatus { open, closed, suspended }

class CashierSession {
  final String id;
  final String tenantId;
  final String branchId;
  final String cashierId;
  final String? deviceId;
  final double openingFloat;
  final double? closingFloat;
  final double? expectedFloat;
  final double? cashVariance;
  final double totalSales;
  final double totalReturns;
  final int totalTransactions;
  final CashierSessionStatus status;
  final DateTime openedAt;
  final DateTime? closedAt;
  final String? closedBy;
  final String? notes;

  const CashierSession({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.cashierId,
    this.deviceId,
    required this.openingFloat,
    this.closingFloat,
    this.expectedFloat,
    this.cashVariance,
    required this.totalSales,
    required this.totalReturns,
    required this.totalTransactions,
    required this.status,
    required this.openedAt,
    this.closedAt,
    this.closedBy,
    this.notes,
  });
}
