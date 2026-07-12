/// Mirrors the account_ledger(p_account_id, p_from, p_to) RPC jsonb:
/// opening_balance plus a chronological list of posted lines with a running
/// balance.
class AccountLedgerEntry {
  final DateTime? date;
  final String? entryNumber;
  final String? description;
  final double debit;
  final double credit;
  final double runningBalance;

  const AccountLedgerEntry({
    this.date,
    this.entryNumber,
    this.description,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });
}

class AccountLedger {
  final String accountId;
  final double openingBalance;
  final List<AccountLedgerEntry> entries;

  const AccountLedger({
    required this.accountId,
    required this.openingBalance,
    required this.entries,
  });
}
