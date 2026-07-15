class BranchConfig {
  final String id;
  final String name;
  final String code;
  final String? city;
  final String? country;
  final String currency;
  final String timezone;
  final bool isActive;
  final bool isMain;

  const BranchConfig({
    required this.id,
    required this.name,
    required this.code,
    required this.city,
    required this.country,
    required this.currency,
    required this.timezone,
    required this.isActive,
    required this.isMain,
  });
}
