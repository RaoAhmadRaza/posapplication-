class Branch {
  final String id;
  final String name;
  final String code;
  final bool isMain;
  final bool isDefault;
  final String currency;

  const Branch({
    required this.id,
    required this.name,
    required this.code,
    required this.isMain,
    required this.isDefault,
    this.currency = 'PKR',
  });
}
