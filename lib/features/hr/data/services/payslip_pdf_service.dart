import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/design/format.dart';
import '../../domain/entities/payroll.dart';

/// One-page payslip for a payroll item, printed via Printing.layoutPdf.
class PayslipPdfService {
  Future<Uint8List> generate({
    required PayrollItem item,
    required PayrollRun run,
    required String employerName,
  }) async {
    final doc = pw.Document();
    doc.addPage(_page(item, run, employerName));
    return doc.save();
  }

  /// One document, a page per item — for "print all".
  Future<Uint8List> generateAll({
    required List<PayrollItem> items,
    required PayrollRun run,
    required String employerName,
  }) async {
    final doc = pw.Document();
    for (final item in items) {
      doc.addPage(_page(item, run, employerName));
    }
    return doc.save();
  }

  pw.Page _page(PayrollItem item, PayrollRun run, String employerName) {
    final earnings = <(String, double)>[
      ('Basic', item.basic),
      for (final e in item.allowances.entries) (_label(e.key), e.value),
      if (item.overtimeAmount > 0) ('Overtime', item.overtimeAmount),
    ];
    final deductions = <(String, double)>[
      for (final d in item.deductions.entries) (_label(d.key), d.value),
    ];

    return pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(employerName,
                style: pw.TextStyle(
                    fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Payslip — ${run.period}',
                style: const pw.TextStyle(fontSize: 11)),
            pw.SizedBox(height: 4),
            pw.Text(
                '${run.startDate.toIso8601String().substring(0, 10)} to '
                '${run.endDate.toIso8601String().substring(0, 10)}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.Divider(height: 20),
            pw.Text('Employee: ${item.employeeName ?? item.employeeId}',
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _table('Earnings', earnings)),
                pw.SizedBox(width: 20),
                pw.Expanded(
                    child: _table('Deductions',
                        deductions.isEmpty ? [('None', 0)] : deductions)),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              color: PdfColors.grey200,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('NET PAY',
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text(formatPkr(item.netSalary),
                      style: pw.TextStyle(
                          fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      );
  }

  static String _label(String key) => key.isEmpty
      ? key
      : key[0].toUpperCase() + key.substring(1).replaceAll('_', ' ');

  pw.Widget _table(String title, List<(String, double)> rows) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        for (final (label, amount) in rows)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
                pw.Text(formatPkr(amount),
                    style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),
      ],
    );
  }
}
