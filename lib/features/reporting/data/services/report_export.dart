import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// Exports a report table to PDF (via Printing) or CSV (via share sheet).
class ReportExport {
  static Future<void> pdf({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Text(title,
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: headers,
            data: rows,
            headerStyle: pw.TextStyle(
                fontSize: 9, fontWeight: pw.FontWeight.bold),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
          ),
        ],
      ),
    );
    final bytes = await doc.save();
    await Printing.sharePdf(bytes: bytes, filename: '${_slug(title)}.pdf');
  }

  static Future<void> csv({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final lines = [_csvRow(headers), ...rows.map(_csvRow)].join('\r\n');
    final bytes = Uint8List.fromList(utf8.encode(lines));
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(bytes, mimeType: 'text/csv', name: '${_slug(title)}.csv'),
        ],
      ),
    );
  }

  static String _csvRow(List<String> cells) =>
      cells.map((c) => '"${c.replaceAll('"', '""')}"').join(',');

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');
}
