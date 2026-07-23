/// One account line inside a financial statement (P&L or balance sheet),
/// grouped by account [type]. Amounts are already normalised to the account's
/// natural side by the report RPC.
class ReportLine {
  final String? code;
  final String name;
  final String type;
  final double amount;

  const ReportLine({
    this.code,
    required this.name,
    required this.type,
    required this.amount,
  });
}
