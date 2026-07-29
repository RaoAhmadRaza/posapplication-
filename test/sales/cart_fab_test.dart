import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/widgets/cart_fab.dart';

void main() {
  test('cart fab shows only with items, and never where the cart already is', () {
    expect(showCartFab(0, '/dashboard'), isFalse);
    expect(showCartFab(2, '/dashboard'), isTrue);
    expect(showCartFab(2, '/sales/pos'), isFalse);
    expect(showCartFab(2, '/sales/payment'), isFalse);
    expect(showCartFab(2, '/sales/history'), isTrue);
  });
}
