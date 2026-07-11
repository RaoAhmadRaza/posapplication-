/// Mirrors the payables_aging() RPC jsonb: total payable plus aging buckets and
/// a per-supplier breakdown.
class PayablesAgingSupplier {
  final String supplierId;
  final String supplierName;
  final double balance;
  final int daysOverdue;

  const PayablesAgingSupplier({
    required this.supplierId,
    required this.supplierName,
    required this.balance,
    required this.daysOverdue,
  });
}

class PayablesAging {
  final double totalPayable;
  final double current;
  final double bucket1To30;
  final double bucket31To60;
  final double bucket61To90;
  final double bucket90Plus;
  final List<PayablesAgingSupplier> bySupplier;

  const PayablesAging({
    required this.totalPayable,
    required this.current,
    required this.bucket1To30,
    required this.bucket31To60,
    required this.bucket61To90,
    required this.bucket90Plus,
    required this.bySupplier,
  });

  double balanceFor(String supplierId) {
    for (final s in bySupplier) {
      if (s.supplierId == supplierId) return s.balance;
    }
    return 0;
  }
}
