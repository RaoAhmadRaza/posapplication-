import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/design/format.dart';
import '../../domain/entities/barcode_template.dart';
import '../../domain/entities/product.dart';

class LabelPdfService {
  static const _eap13Pattern = '^\\d{13}\$';

  Future<Uint8List> generate(List<Product> products, BarcodeTemplate template) async {
    final doc = pw.Document();

    final labelW = template.widthMm * PdfPageFormat.mm;
    final labelH = template.heightMm * PdfPageFormat.mm;

    final pageFormat = PdfPageFormat.a4;
    const marginPt = 8.0;
    final usableW = pageFormat.width - marginPt * 2;
    final usableH = pageFormat.height - marginPt * 2;

    final rowSpacing = 4.0;
    final colSpacing = 4.0;
    final cols = ((usableW + colSpacing) / (labelW + colSpacing)).floor().clamp(1, 10);
    final rows = ((usableH + rowSpacing) / (labelH + rowSpacing)).floor().clamp(1, 20);
    final perPage = cols * rows;

    final layout = template.layout;
    final showName = layout['showName'] as bool? ?? true;
    final showBarcode = layout['showBarcode'] as bool? ?? true;
    final showPrice = layout['showPrice'] as bool? ?? true;

    for (var i = 0; i < products.length; i += perPage) {
      final pageProducts = products.skip(i).take(perPage).toList();
      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.all(marginPt),
          build: (context) {
            return pw.Column(
              children: List.generate(
                rows.clamp(1, (pageProducts.length / cols).ceil()),
                (row) {
                  final start = row * cols;
                  final end = (start + cols).clamp(0, pageProducts.length);
                  final rowProducts =
                      pageProducts.sublist(start, end);
                  return pw.Padding(
                    padding: pw.EdgeInsets.only(
                      bottom: row < rows - 1 ? rowSpacing : 0,
                    ),
                    child: pw.Row(
                      children: [
                        for (var j = 0; j < rowProducts.length; j++)
                          pw.Padding(
                            padding: pw.EdgeInsets.only(
                              right: j < rows - 1 ? colSpacing : 0,
                            ),
                            child: pw.SizedBox(
                              width: labelW,
                              height: labelH,
                              child: _buildLabel(
                                rowProducts[j],
                                template,
                                showName: showName,
                                showBarcode: showBarcode,
                                showPrice: showPrice,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      );
    }

    return doc.save();
  }

  pw.Widget _buildLabel(
    Product product,
    BarcodeTemplate template, {
    required bool showName,
    required bool showBarcode,
    required bool showPrice,
  }) {
    final code = (product.barcode != null && product.barcode!.isNotEmpty)
        ? product.barcode!
        : product.sku;

    final barcode = _barcodeFor(code, template.format);

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.grey400,
          width: 0.5,
        ),
      ),
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (showName)
            pw.Text(
              product.name,
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
              ),
              maxLines: 2,
              textAlign: pw.TextAlign.center,
              overflow: pw.TextOverflow.clip,
            ),
          if (showBarcode && barcode != null)
            pw.Expanded(
              child: pw.Center(
                child: pw.BarcodeWidget(
                  data: code,
                  barcode: barcode,
                  width: template.widthMm * PdfPageFormat.mm * 0.85,
                  height: (template.heightMm * PdfPageFormat.mm * 0.55)
                      .clamp(20, double.infinity),
                  drawText: false,
                  color: PdfColors.black,
                  backgroundColor: PdfColors.white,
                ),
              ),
            ),
          if (showPrice)
            pw.Text(
              formatPkr(product.sellingPrice),
              style: pw.TextStyle(fontSize: 7),
              textAlign: pw.TextAlign.center,
            ),
        ],
      ),
    );
  }

  bc.Barcode? _barcodeFor(String value, String format) {
    switch (format) {
      case 'EAN13':
        if (RegExp(_eap13Pattern).hasMatch(value)) {
          return bc.Barcode.ean13();
        }
        return bc.Barcode.code128();
      case 'QR':
        return bc.Barcode.qrCode();
      case 'CODE128':
      default:
        return bc.Barcode.code128();
    }
  }
}
