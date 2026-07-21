import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/design/app_theme.dart';
import 'package:pos_app/features/inventory/domain/entities/product.dart';
import 'package:pos_app/features/inventory/domain/entities/stock_level.dart';
import 'package:pos_app/features/sales/presentation/widgets/pos/product_grid.dart';

/// The POS catalogue tile is laid out inside a fixed-height grid cell, so any
/// mismatch between the tile's content and the height the grid derives shows up
/// as a RenderFlex overflow. These tests pump the grid at several widths and
/// text scales and fail on the first layout exception.
void main() {
  Product product(String id, String name) => Product(
        id: id,
        tenantId: 't1',
        sku: 'SKU-$id-LONG-ENOUGH-TO-CLIP',
        name: name,
        type: ProductType.standard,
        unitOfMeasure: 'pcs',
        costPrice: 900,
        sellingPrice: 1113.5,
        taxRate: 0,
        taxInclusive: false,
        reorderPoint: 4,
        reorderQty: 10,
        isActive: true,
        status: ProductStatus.active,
      );

  StockLevel level(String id, double qty) => StockLevel(
        productId: id,
        productName: 'p',
        productSku: 's',
        reorderPoint: 4,
        qtyOnHand: qty,
        qtyReserved: 0,
        qtyInTransit: 0,
        avgCost: 0,
      );

  Widget harness({
    required Size size,
    required bool online,
    double textScale = 1,
    Map<String, StockLevel> stock = const {},
  }) {
    final products = [
      product('1', 'gpu'),
      // A two-line name is the tallest the name row ever gets.
      product('2', 'Back camera lens assembly iPhone 13 Pro Max'),
      product('3', 'Body'),
      product('4', 'Ringer Module'),
    ];
    return MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
      ),
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SizedBox(
            width: size.width,
            height: size.height,
            child: ProductGrid(
              products: products,
              stockMap: stock,
              online: online,
              cartQtyOf: (_) => 0,
              onAdd: (_) {},
            ),
          ),
        ),
      ),
    );
  }

  for (final width in [360.0, 520.0, 828.0, 1180.0]) {
    testWidgets('tile does not overflow at ${width.toInt()}px wide',
        (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        harness(size: Size(width, 900), online: true),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tile does not overflow at 1.3x text scale', (tester) async {
    tester.view.physicalSize = const Size(828, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(size: const Size(828, 900), online: true, textScale: 1.3),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('a missing stock level reads as out of stock when online',
      (tester) async {
    tester.view.physicalSize = const Size(828, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(size: const Size(828, 900), online: true),
    );
    await tester.pump();

    expect(find.text('Out of stock'), findsWidgets);
    expect(find.text('Stock not cached'), findsNothing);
  });

  testWidgets('a missing stock level reads as uncached when offline',
      (tester) async {
    tester.view.physicalSize = const Size(828, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(size: const Size(828, 900), online: false),
    );
    await tester.pump();

    expect(find.text('Stock not cached'), findsWidgets);
    expect(find.text('Out of stock'), findsNothing);
  });

  testWidgets('stock levels drive the in-stock and low-stock labels',
      (tester) async {
    tester.view.physicalSize = const Size(828, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      harness(
        size: const Size(828, 900),
        online: true,
        stock: {'1': level('1', 12), '3': level('3', 3)},
      ),
    );
    await tester.pump();

    expect(find.text('In stock · 12'), findsOneWidget);
    expect(find.text('Low · 3 left'), findsOneWidget);
  });
}
