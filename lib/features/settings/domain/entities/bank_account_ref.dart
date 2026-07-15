/// A bank account the user can link to a payment method (drives the GL split).
class BankAccountRef {
  final String id;
  final String accountName;
  final String bankName;

  const BankAccountRef({
    required this.id,
    required this.accountName,
    required this.bankName,
  });

  String get label => '$accountName · $bankName';
}
