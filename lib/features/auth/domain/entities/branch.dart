class Branch {
  final String id;
  final String name;
  final String code;
  final bool isMain;
  final bool isDefault;

  const Branch({
    required this.id,
    required this.name,
    required this.code,
    required this.isMain,
    required this.isDefault,
  });
}
