/// Mirrors the receivables_aging() RPC jsonb: total receivable plus aging
/// buckets and a per-customer breakdown.
class ReceivablesAgingCustomer {
  final String customerId;
  final String customerName;
  final double balance;
  final int daysOverdue;

  const ReceivablesAgingCustomer({
    required this.customerId,
    required this.customerName,
    required this.balance,
    required this.daysOverdue,
  });
}

class ReceivablesAging {
  final double totalReceivable;
  final double current;
  final double bucket1To30;
  final double bucket31To60;
  final double bucket61To90;
  final double bucket90Plus;
  final List<ReceivablesAgingCustomer> byCustomer;

  const ReceivablesAging({
    required this.totalReceivable,
    required this.current,
    required this.bucket1To30,
    required this.bucket31To60,
    required this.bucket61To90,
    required this.bucket90Plus,
    required this.byCustomer,
  });

  double balanceFor(String customerId) {
    for (final c in byCustomer) {
      if (c.customerId == customerId) return c.balance;
    }
    return 0;
  }
}
