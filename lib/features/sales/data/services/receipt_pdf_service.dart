import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/design/format.dart';

class ReceiptPdfService {
  Future<Uint8List> buildReceipt(Map<String, dynamic> invoiceDetail) async {
    final invoice = invoiceDetail;
    final items = (invoice['invoice_items'] as List<dynamic>?) ?? [];
    final payments = (invoice['payments'] as List<dynamic>?) ?? [];

    final doc = pw.Document();
    final theme = pw.ThemeData.withFont(
      base: await PdfGoogleFonts.openSansRegular(),
      bold: await PdfGoogleFonts.openSansBold(),
    );

    doc.addPage(
      // pw.Page, not pw.MultiPage: roll80 has an infinite height, which
      // MultiPage asserts against. Page grows the roll to fit the content.
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        theme: theme,
        margin: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        build: (ctx) => pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            _header(invoice),
            pw.SizedBox(height: 8),
            _divider(),
            pw.SizedBox(height: 8),
            ...items.map((item) => _lineItem(item as Map<String, dynamic>)),
            pw.SizedBox(height: 4),
            _divider(),
            pw.SizedBox(height: 8),
            _totals(invoice),
            pw.SizedBox(height: 8),
            _divider(),
            pw.SizedBox(height: 8),
            ...payments.map((p) => _paymentLine(p as Map<String, dynamic>)),
            pw.SizedBox(height: 16),
            _footer(),
          ],
        ),
      ),
    );

    return doc.save();
  }

  pw.Widget _header(Map<String, dynamic> invoice) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('LUMINA POS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Tax Invoice', style: const pw.TextStyle(fontSize: 10)),
        pw.SizedBox(height: 8),
        pw.Text(invoice['invoice_number']?.toString() ?? '', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Date: ${_formatDate(invoice['created_at']?.toString())}', style: const pw.TextStyle(fontSize: 9)),
        pw.Text('Branch: ${invoice['branch_id']?.toString().substring(0, 8) ?? ''}', style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  pw.Widget _lineItem(Map<String, dynamic> item) {
    final qty = double.tryParse(item['qty']?.toString() ?? '0') ?? 0;
    final price = double.tryParse(item['unit_price']?.toString() ?? '0') ?? 0;
    final total = double.tryParse(item['line_total']?.toString() ?? '0') ?? 0;
    final desc = item['description']?.toString() ?? '';
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('${qty.toStringAsFixed(0)} x ${formatPkr(price)}', style: const pw.TextStyle(fontSize: 9)),
                if (desc.isNotEmpty)
                  pw.Text(desc, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
              ],
            ),
          ),
          pw.Expanded(
            flex: 2,
            child: pw.Text(formatPkr(total), style: const pw.TextStyle(fontSize: 9), textAlign: pw.TextAlign.right),
          ),
        ],
      ),
    );
  }

  pw.Widget _totals(Map<String, dynamic> invoice) {
    final discount = double.tryParse(invoice['discount_total']?.toString() ?? '0') ?? 0;
    final tax = double.tryParse(invoice['tax_total']?.toString() ?? '0') ?? 0;
    final grand = double.tryParse(invoice['grand_total']?.toString() ?? '0') ?? 0;
    final paid = double.tryParse(invoice['paid_amount']?.toString() ?? '0') ?? 0;
    final change = double.tryParse(invoice['change_amount']?.toString() ?? '0') ?? 0;
    final balance = double.tryParse(invoice['balance']?.toString() ?? '0') ?? 0;

    return pw.Column(
      children: [
        if (discount > 0) _totalRow('Discount', -discount),
        if (tax > 0) _totalRow('Tax', tax),
        _totalRow('TOTAL', grand, bold: true),
        pw.SizedBox(height: 4),
        _totalRow('Paid', paid),
        if (change > 0) _totalRow('Change', change),
        if (balance > 0) _totalRow('Balance Due', balance, bold: true),
      ],
    );
  }

  pw.Widget _totalRow(String label, double value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(formatPkr(value), style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  pw.Widget _paymentLine(Map<String, dynamic> payment) {
    final method = payment['method']?.toString() ?? '';
    final amount = double.tryParse(payment['amount']?.toString() ?? '0') ?? 0;
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(method, style: const pw.TextStyle(fontSize: 9)),
        pw.Text(formatPkr(amount), style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  pw.Widget _footer() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('Thank you for your business.', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 4),
        pw.Text('Software by Lumina POS', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
      ],
    );
  }

  pw.Widget _divider() {
    return pw.Container(
      height: 0.5,
      color: PdfColors.grey400,
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  /// Returns false when the platform declined to share (Windows returns false
  /// with no exception when no app is registered for .pdf).
  Future<bool> shareReceipt(Uint8List pdfBytes, String invoiceNumber, {String? customerPhone}) async {
    final shared = await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'receipt_$invoiceNumber.pdf',
    );

    if (customerPhone != null && customerPhone.isNotEmpty) {
      final text = 'Thank you for your business.\nInvoice: $invoiceNumber';
      final encoded = Uri.encodeComponent('$text — Lumina POS');
      final uri = Uri.parse('https://wa.me/$customerPhone?text=$encoded');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }

    return shared;
  }
}
