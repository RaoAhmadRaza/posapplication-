import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/sales/data/services/receipt_pdf_service.dart';

/// Guards the roll80 page format: pw.MultiPage asserts on an infinite page
/// height, which made buildReceipt throw and the Print & share button dead.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('receipt pdf builds for a roll80 receipt', () async {
    final bytes = await ReceiptPdfService().buildReceipt({
      'invoice_number': 'INV-BR01-000006',
      'created_at': '2026-07-26T12:29:00Z',
      'branch_id': '11111111-2222-3333-4444-555555555555',
      'grand_total': '1287.00',
      'paid_amount': '2200.00',
      'change_amount': '913.00',
      'balance': '0',
      'invoice_items': [
        {
          'description': 'Item',
          'qty': '1',
          'unit_price': '1100.00',
          'line_total': '1287.00',
        },
      ],
      'payments': [
        {'method': 'cash', 'amount': '1100.00'},
        {'method': 'cash', 'amount': '1100.00'},
      ],
    });

    expect(bytes.length, greaterThan(1000));
  });
}
