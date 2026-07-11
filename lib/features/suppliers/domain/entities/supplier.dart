enum SupplierStatus { active, inactive, blacklisted }

class Supplier {
  final String id;
  final String tenantId;
  final String name;
  final String? contactPerson;
  final String? phone;
  final String? email;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? taxNumber;
  final int paymentTerms;
  final String currency;
  final String? bankName;
  final String? bankAccountNumber;
  final double openingBalance;
  final SupplierStatus status;
  final List<String>? tags;
  final String? notes;
  final DateTime createdAt;

  const Supplier({
    required this.id,
    required this.tenantId,
    required this.name,
    this.contactPerson,
    this.phone,
    this.email,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.taxNumber,
    required this.paymentTerms,
    required this.currency,
    this.bankName,
    this.bankAccountNumber,
    required this.openingBalance,
    required this.status,
    this.tags,
    this.notes,
    required this.createdAt,
  });
}
