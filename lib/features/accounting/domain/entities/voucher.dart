enum VoucherType { payment, receipt, contra, journal }

enum EntityType { customer, supplier }

class Voucher {
  final String id;
  final String tenantId;
  final String voucherNumber;
  final VoucherType type;
  final String? journalEntryId;
  final double amount;
  final EntityType? partyType;
  final String? partyId;
  final String? bankAccountId;
  final String? paymentMethod;
  final String? reference;
  final String? description;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;

  const Voucher({
    required this.id,
    required this.tenantId,
    required this.voucherNumber,
    required this.type,
    this.journalEntryId,
    required this.amount,
    this.partyType,
    this.partyId,
    this.bankAccountId,
    this.paymentMethod,
    this.reference,
    this.description,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
  });
}
