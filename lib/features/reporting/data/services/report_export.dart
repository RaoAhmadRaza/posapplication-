import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Exports a report table to PDF or CSV through the platform save dialog.
/// Returns the saved path, or null if the user cancelled.
///
/// Save dialog rather than a share sheet: this is a desktop-first app, and
/// share_plus rejects files on Windows/Linux while Printing.sharePdf only
/// shells a temp file open.
class ReportExport {
  static Future<String?> pdf({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) async =>
      _save(title, 'pdf', await buildPdfBytes(
          title: title, headers: headers, rows: rows));

  /// Renders the table to PDF bytes. Split out from [pdf] so it is testable
  /// without a save dialog.
  static Future<Uint8List> buildPdfBytes({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) async {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        // A spanning table counts one "same widget" page per page it covers,
        // so the default cap of 20 rejects any report past ~700 rows.
        // ponytail: flat cap, paginate the export if a report ever exceeds it.
        maxPages: 5000,
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
    return doc.save();
  }

  static Future<String?> csv({
    required String title,
    required List<String> headers,
    required List<List<String>> rows,
  }) {
    // Leading BOM so Excel reads the file as UTF-8.
    final text =
        '﻿${[_csvRow(headers), ...rows.map(_csvRow)].join('\r\n')}';
    return _save(title, 'csv', Uint8List.fromList(utf8.encode(text)));
  }

  static Future<String?> _save(String title, String ext, Uint8List bytes) =>
      FilePicker.saveFile(
        dialogTitle: 'Save ${ext.toUpperCase()} export',
        fileName: '${_slug(title)}.$ext',
        type: FileType.custom,
        allowedExtensions: [ext],
        bytes: bytes,
        lockParentWindow: true,
      );

  static String _csvRow(List<String> cells) =>
      cells.map((c) => '"${c.replaceAll('"', '""')}"').join(',');

  static String _slug(String s) =>
      s.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '_');
}
