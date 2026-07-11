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
      creditTerms: (json['credit_terms'] as num?)?.toInt() ?? 0,
      loyaltyPoints: (json['loyalty_points'] as num?)?.toInt() ?? 0,
      openingBalance: double.tryParse(json['opening_balance'].toString()) ?? 0,
      status: _parseStatus(json['status'] as String?),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Insert payload — writable columns only, whitelisted so callers can persist
  /// EVERY field the entity exposes (credit_limit, credit_terms, loyalty_points,
  /// opening_balance, group_id, tags, …). Mirrors SupplierModel.toInsert/toUpdate.
  /// tenant_id + audit ids are added in the datasource.
  static Map<String, dynamic> toInsert(Map<String, dynamic> form) =>
      _writable(form);

  static Map<String, dynamic> toUpdate(Map<String, dynamic> form) =>
      _writable(form);

  static Map<String, dynamic> _writable(Map<String, dynamic> f) {
    final out = <String, dynamic>{};
    void put(String key) {
      if (f.containsKey(key)) out[key] = f[key];
    }

    for (final k in const [
      'name',
      'phone',
      'phone_secondary',
      'email',
      'address_line1',
      'address_line2',
      'city',
      'state',
      'postal_code',
      'country',
      'tax_number',
      'group_id',
      'credit_limit',
      'credit_terms',
      'loyalty_points',
      'opening_balance',
      'status',
      'tags',
      'notes',
    ]) {
      put(k);
    }
    return out;
  }

  static String statusToDb(CustomerStatus s) => switch (s) {
        CustomerStatus.active => 'ACTIVE',
        CustomerStatus.inactive => 'INACTIVE',
        CustomerStatus.blacklisted => 'BLACKLISTED',
      };

  static CustomerStatus _parseStatus(String? s) {
    return switch ((s ?? 'ACTIVE').toUpperCase()) {
      'ACTIVE' => CustomerStatus.active,
      'INACTIVE' => CustomerStatus.inactive,
      'BLACKLISTED' => CustomerStatus.blacklisted,
      _ => CustomerStatus.active,
    };
  }
}
