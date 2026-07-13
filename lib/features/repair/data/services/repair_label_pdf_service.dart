import 'dart:typed_data';

import 'package:barcode/barcode.dart' as bc;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/repair_job.dart';

/// Renders a single physical device-tag label: QR of the job number + text
/// (job number, device, customer). Printed via Printing.layoutPdf.
class RepairLabelPdfService {
  Future<Uint8List> generate(RepairJob job) async {
    final doc = pw.Document();
    final device = [job.deviceType, job.deviceBrand, job.deviceModel]
        .where((e) => e != null && e.isNotEmpty)
        .join(' ');

    // 62mm x 40mm — a common device-tag label size.
    final format = PdfPageFormat(
      62 * PdfPageFormat.mm,
      40 * PdfPageFormat.mm,
      marginAll: 4 * PdfPageFormat.mm,
    );

    doc.addPage(
      pw.Page(
        pageFormat: format,
        build: (context) {
          return pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.BarcodeWidget(
                data: job.jobNumber,
                barcode: bc.Barcode.qrCode(),
                width: 60,
                height: 60,
                drawText: false,
                color: PdfColors.black,
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(job.jobNumber,
                        style: pw.TextStyle(
                            fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 2),
                    pw.Text(device,
                        style: const pw.TextStyle(fontSize: 8),
                        maxLines: 2,
                        overflow: pw.TextOverflow.clip),
                    if (job.customerName != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(job.customerName!,
                          style: const pw.TextStyle(fontSize: 8),
                          maxLines: 1,
                          overflow: pw.TextOverflow.clip),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }
}
