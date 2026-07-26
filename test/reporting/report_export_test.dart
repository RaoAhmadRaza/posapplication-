import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/reporting/data/services/report_export.dart';

void main() {
  test('renders a report far past MultiPage\'s default 20-page cap', () async {
    final bytes = await ReportExport.buildPdfBytes(
      title: 'Inventory Valuation',
      headers: const ['Product', 'SKU', 'Qty', 'Value'],
      rows: List.generate(
        1200,
        (i) => ['Product $i', 'SKU$i', '$i', '${i * 100}.00'],
      ),
    );
    expect(bytes.length, greaterThan(0));
  });
}
