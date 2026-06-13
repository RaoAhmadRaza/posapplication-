class BarcodeTemplate {
  final String id;
  final String tenantId;
  final String name;
  final String format;
  final int widthMm;
  final int heightMm;
  final Map<String, dynamic> layout;
  final bool isDefault;

  const BarcodeTemplate({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.format,
    required this.widthMm,
    required this.heightMm,
    required this.layout,
    required this.isDefault,
  });
}
