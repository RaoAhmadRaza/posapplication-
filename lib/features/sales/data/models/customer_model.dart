import '../../domain/entities/customer.dart';

class CustomerModel {
  static Customer fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      phoneSecondary: json['phone_secondary'] as String?,
      email: json['email'] as String?,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      taxNumber: json['tax_number'] as String?,
      groupId: json['group_id'] as String?,
      creditLimit: double.tryParse(json['credit_limit'].toString()) ?? 0,
      creditTerms: json['credit_terms'] as int,
      loyaltyPoints: json['loyalty_points'] as int,
      openingBalance: double.tryParse(json['opening_balance'].toString()) ?? 0,
      status: _parseStatus(json['status'] as String),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static Map<String, dynamic> toJson(Customer c) {
    return {
      'name': c.name,
      if (c.phone != null) 'phone': c.phone,
      if (c.phoneSecondary != null) 'phone_secondary': c.phoneSecondary,
      if (c.email != null) 'email': c.email,
      if (c.addressLine1 != null) 'address_line1': c.addressLine1,
      if (c.addressLine2 != null) 'address_line2': c.addressLine2,
      if (c.city != null) 'city': c.city,
      if (c.state != null) 'state': c.state,
      if (c.postalCode != null) 'postal_code': c.postalCode,
      if (c.country != null) 'country': c.country,
      if (c.taxNumber != null) 'tax_number': c.taxNumber,
      if (c.notes != null) 'notes': c.notes,
    };
  }

  static CustomerStatus _parseStatus(String s) {
    return switch (s.toUpperCase()) {
      'ACTIVE' => CustomerStatus.active,
      'INACTIVE' => CustomerStatus.inactive,
      'BLACKLISTED' => CustomerStatus.blacklisted,
      _ => CustomerStatus.active,
    };
  }
}
