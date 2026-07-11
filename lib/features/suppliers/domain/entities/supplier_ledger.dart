/// Mirrors the supplier_ledger(p_supplier_id) RPC jsonb: opening_balance,
/// current_balance, and a chronological list of INVOICE (debit) / PAYMENT
/// (credit) entries with a running balance.
class SupplierLedgerEntry {
  final String kind; // INVOICE | PAYMENT
  final String? reference;
  final String? status;
  final double debit;
  final double credit;
  final double runningBalance;
  final DateTime? timestamp;

  const SupplierLedgerEntry({
    required this.kind,
    this.reference,
    this.status,
    required this.debit,
    required this.credit,
    required this.runningBalance,
    this.timestamp,
  });
}

class SupplierLedger {
  final String supplierId;
  final double openingBalance;
  final double currentBalance;
  final List<SupplierLedgerEntry> entries;

  const SupplierLedger({
    required this.supplierId,
    required this.openingBalance,
    required this.currentBalance,
    required this.entries,
  });
}
