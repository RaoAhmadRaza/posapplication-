import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/design/app_theme.dart';
import 'package:pos_app/core/design/widgets/app_hover.dart';

/// The overlay is always mounted and only its opacity changes, so the check is
/// on that opacity — 0 at rest, 1 while the pointer is inside.
double _tintOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(find.byType(AnimatedOpacity))
    .opacity;

void main() {
  Future<void> pump(WidgetTester tester, {bool enabled = true}) =>
      tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: AppHover(
              enabled: enabled,
              child: const SizedBox(width: 100, height: 100),
            ),
          ),
        ),
      ));

  testWidgets('tints while the pointer is over it, clears on exit',
      (tester) async {
    await pump(tester);
    expect(_tintOpacity(tester), 0);

    final pointer = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await pointer.addPointer(location: Offset.zero);
    addTearDown(pointer.removePointer);

    await pointer.moveTo(tester.getCenter(find.byType(AppHover)));
    await tester.pump();
    expect(_tintOpacity(tester), 1);

    await pointer.moveTo(Offset.zero);
    await tester.pump();
    expect(_tintOpacity(tester), 0);
  });

  // A loose Stack would let a min-sized child shrink inside a tight grid cell,
  // leaving the filled overlay spilling past the card it is meant to tint.
  testWidgets('keeps the child filling tight constraints', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: AppHover(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [SizedBox(height: 20, width: 20)],
            ),
          ),
        ),
      ),
    ));
    expect(tester.getSize(find.byType(Column)), const Size(200, 200));
  });

  testWidgets('disabled passes the child straight through', (tester) async {
    await pump(tester, enabled: false);
    expect(find.byType(AnimatedOpacity), findsNothing);
  });
}
