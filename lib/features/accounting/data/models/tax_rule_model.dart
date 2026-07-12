import '../../domain/entities/tax_rule.dart';

class TaxRuleModel {
  static TaxRule fromJson(Map<String, dynamic> json) {
    return TaxRule(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      rate: double.tryParse(json['rate'].toString()) ?? 0,
      mode: _parseMode(json['mode'] as String?),
      isDefault: json['is_default'] as bool? ?? false,
      appliesTo: json['applies_to'] as String?,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      effectiveFrom: json['effective_from'] == null
          ? null
          : DateTime.tryParse(json['effective_from'].toString()),
      effectiveUntil: json['effective_until'] == null
          ? null
          : DateTime.tryParse(json['effective_until'].toString()),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static String modeToDb(TaxMode m) => switch (m) {
    TaxMode.inclusive => 'INCLUSIVE',
    TaxMode.exclusive => 'EXCLUSIVE',
  };

  static TaxMode _parseMode(String? s) {
    return switch ((s ?? 'EXCLUSIVE').toUpperCase()) {
      'INCLUSIVE' => TaxMode.inclusive,
      'EXCLUSIVE' => TaxMode.exclusive,
      _ => TaxMode.exclusive,
    };
  }
}
