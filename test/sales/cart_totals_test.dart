import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/features/sales/domain/entities/cart_line.dart';
import 'package:pos_app/features/sales/presentation/controllers/pos_cart_controller.dart';

/// The cart total has to equal what create_sale will compute, to the cent. When
/// it lands under, the tender does not cover the invoice, the RPC classifies the
/// sale as credit and refuses it with ERR_CREDIT_REQUIRES_CUSTOMER — which at
/// the counter looked like "Enter did nothing".
void main() {
  CartLine lineOf({required double unit, double qty = 1, double taxPct = 0}) =>
      CartLine(
        id: '1',
        productId: 'p1',
        productName: 'LCD Unit',
        qty: qty,
        unitPrice: unit,
        taxPct: taxPct,
      );

  test('tax keeps its fraction instead of rounding to whole units', () {
    // round(1750 * 17 / 100, 4) = 297.5 server-side. Rounding to 298 overstated
    // the total; the same rounding on a .4 fraction understates it, and that is
    // the direction that gets the sale refused.
    final line = lineOf(unit: 1750, taxPct: 17);
    expect(line.taxAmount, 297.5);
    expect(line.lineTotal, 2047.5);

    final downward = lineOf(unit: 200, taxPct: 17.2);
    expect(downward.taxAmount, 34.4);
    expect(downward.lineTotal, 234.4);
  });

  test('a zero-rated line is untaxed', () {
    expect(lineOf(unit: 1750).lineTotal, 1750);
  });

  test('clearPayments drops the last attempt tender but keeps the cart', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cart = container.read(posCartProvider.notifier);

    cart.addLine(
      productId: 'p1',
      productName: 'LCD Unit',
      qty: 1,
      unitPrice: 1750,
      taxPct: 17,
    );
    cart.addPayment(PaymentMethodLabel.cash, 2047.5);
    expect(container.read(posCartProvider).paid, 2047.5);

    // A refused checkout is retried from the same tender rows: without this the
    // second attempt appended and the sale went through at double the money.
    cart.clearPayments();
    expect(container.read(posCartProvider).payments, isEmpty);
    expect(container.read(posCartProvider).lines, hasLength(1));

    cart.addPayment(PaymentMethodLabel.cash, 2047.5);
    expect(container.read(posCartProvider).paid, 2047.5);
    expect(container.read(posCartProvider).balance, 0);
  });
}
