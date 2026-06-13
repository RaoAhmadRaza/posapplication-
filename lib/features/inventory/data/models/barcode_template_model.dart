import '../../domain/entities/barcode_template.dart';

class BarcodeTemplateModel {
  static BarcodeTemplate fromJson(Map<String, dynamic> json) {
    final rawLayout = json['layout_json'];
    final layout = rawLayout is Map<String, dynamic> ? rawLayout : <String, dynamic>{};

    return BarcodeTemplate(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      format: json['format'] as String,
      widthMm: json['width_mm'] as int,
      heightMm: json['height_mm'] as int,
      layout: layout,
      isDefault: json['is_default'] as bool,
    );
  }

  static Map<String, dynamic> toJson(BarcodeTemplate t) {
    return {
      'name': t.name,
      'format': t.format,
      'width_mm': t.widthMm,
      'height_mm': t.heightMm,
      'layout_json': t.layout,
      'is_default': t.isDefault,
    };
  }
}
