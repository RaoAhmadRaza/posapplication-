/// Mirrors the customer_ledger(p_customer_id) RPC jsonb: opening_balance,
/// current_balance (true net, can be negative on overpayment), outstanding
/// (guard basis — invoices.balance, clamped >= 0), and a chronological list of
/// INVOICE (debit) / PAYMENT (credit) entries with a running balance.
class CustomerLedgerEntry {
  final String kind; // INVOICE | PAYMENT
  final String? reference;
  final String? status;
  final double debit;
  final double credit;
  final double runningBalance;
  final DateTime? timestamp;

  const CustomerLedgerEntry({
    required this.kind,
    this.reference,
    this.status,
    required this.debit,
    required this.credit,
    required this.runningBalance,
    this.timestamp,
  });
}

class CustomerLedger {
  final String customerId;
  final double openingBalance;
  final double currentBalance;
  final double outstanding;
  final List<CustomerLedgerEntry> entries;

  const CustomerLedger({
    required this.customerId,
    required this.openingBalance,
    required this.currentBalance,
    required this.outstanding,
    required this.entries,
  });
}
