/// tenants.settings_json — a free-form config map with documented convention keys.
class TenantSettings {
  final String tenantName;
  final Map<String, dynamic> json;

  const TenantSettings({required this.tenantName, required this.json});

  String get businessAddress => (json['business_address'] ?? '').toString();
  String get phone => (json['phone'] ?? '').toString();
  String get logoUrl => (json['logo_url'] ?? '').toString();
  String get receiptFooter => (json['receipt_footer'] ?? '').toString();
  String get ntn => (json['ntn'] ?? '').toString();
}
