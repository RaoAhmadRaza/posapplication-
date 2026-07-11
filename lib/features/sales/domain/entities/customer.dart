enum CustomerStatus { active, inactive, blacklisted }

class Customer {
  final String id;
  final String tenantId;
  final String name;
  final String? phone;
  final String? phoneSecondary;
  final String? email;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? taxNumber;
  final String? groupId;
  final double creditLimit;
  final int creditTerms;
  final int loyaltyPoints;
  final double openingBalance;
  final CustomerStatus status;
  final List<String>? tags;
  final String? notes;
  final DateTime createdAt;

  const Customer({
    required this.id,
    required this.tenantId,
    required this.name,
    this.phone,
    this.phoneSecondary,
    this.email,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.taxNumber,
    this.groupId,
    required this.creditLimit,
    required this.creditTerms,
    required this.loyaltyPoints,
    required this.openingBalance,
    required this.status,
    this.tags,
    this.notes,
    required this.createdAt,
  });
}
