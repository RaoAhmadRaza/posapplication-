import '../../domain/entities/voucher.dart';

class VoucherModel {
  static Voucher fromJson(Map<String, dynamic> json) {
    return Voucher(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      voucherNumber: json['voucher_number'] as String,
      type: _parseType(json['type'] as String?),
      journalEntryId: json['journal_entry_id'] as String?,
      amount: double.tryParse(json['amount'].toString()) ?? 0,
      partyType: _parseParty(json['party_type'] as String?),
      partyId: json['party_id'] as String?,
      bankAccountId: json['bank_account_id'] as String?,
      paymentMethod: json['payment_method'] as String?,
      reference: json['reference'] as String?,
      description: json['description'] as String?,
      approvedBy: json['approved_by'] as String?,
      approvedAt: json['approved_at'] == null
          ? null
          : DateTime.tryParse(json['approved_at'].toString()),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static String typeToDb(VoucherType t) => switch (t) {
    VoucherType.payment => 'PAYMENT',
    VoucherType.receipt => 'RECEIPT',
    VoucherType.contra => 'CONTRA',
    VoucherType.journal => 'JOURNAL',
  };

  static String partyToDb(EntityType t) => switch (t) {
    EntityType.customer => 'CUSTOMER',
    EntityType.supplier => 'SUPPLIER',
  };

  static VoucherType _parseType(String? s) {
    return switch ((s ?? 'PAYMENT').toUpperCase()) {
      'PAYMENT' => VoucherType.payment,
      'RECEIPT' => VoucherType.receipt,
      'CONTRA' => VoucherType.contra,
      'JOURNAL' => VoucherType.journal,
      _ => VoucherType.payment,
    };
  }

  static EntityType? _parseParty(String? s) {
    return switch (s?.toUpperCase()) {
      'CUSTOMER' => EntityType.customer,
      'SUPPLIER' => EntityType.supplier,
      _ => null,
    };
  }
}
