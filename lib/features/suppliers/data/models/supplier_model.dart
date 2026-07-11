import '../../domain/entities/supplier.dart';

class SupplierModel {
  static Supplier fromJson(Map<String, dynamic> json) {
    return Supplier(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      contactPerson: json['contact_person'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      addressLine1: json['address_line1'] as String?,
      addressLine2: json['address_line2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      taxNumber: json['tax_number'] as String?,
      paymentTerms: (json['payment_terms'] as num?)?.toInt() ?? 30,
      currency: json['currency'] as String? ?? 'PKR',
      bankName: json['bank_name'] as String?,
      bankAccountNumber: json['bank_account_number'] as String?,
      openingBalance: double.tryParse(json['opening_balance'].toString()) ?? 0,
      status: _parseStatus(json['status'] as String?),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Insert payload — includes tenant_id + audit ids for the RLS gate (mirrors
  /// the customers createCustomer tenant_id fix). Only writable columns.
  static Map<String, dynamic> toInsert(Map<String, dynamic> form) {
    return {..._writable(form)};
  }

  static Map<String, dynamic> toUpdate(Map<String, dynamic> form) {
    return {..._writable(form)};
  }

  static Map<String, dynamic> _writable(Map<String, dynamic> f) {
    final out = <String, dynamic>{};
    void put(String key) {
      if (f.containsKey(key)) out[key] = f[key];
    }

    for (final k in const [
      'name',
      'contact_person',
      'phone',
      'email',
      'address_line1',
      'address_line2',
      'city',
      'state',
      'postal_code',
      'country',
      'tax_number',
      'payment_terms',
      'currency',
      'bank_name',
      'bank_account_number',
      'opening_balance',
      'status',
      'tags',
      'notes',
    ]) {
      put(k);
    }
    return out;
  }

  static String statusToDb(SupplierStatus s) => switch (s) {
        SupplierStatus.active => 'ACTIVE',
        SupplierStatus.inactive => 'INACTIVE',
        SupplierStatus.blacklisted => 'BLACKLISTED',
      };

  static SupplierStatus _parseStatus(String? s) {
    return switch ((s ?? 'ACTIVE').toUpperCase()) {
      'ACTIVE' => SupplierStatus.active,
      'INACTIVE' => SupplierStatus.inactive,
      'BLACKLISTED' => SupplierStatus.blacklisted,
      _ => SupplierStatus.active,
    };
  }
}
