import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pos_app/features/sales/presentation/widgets/enter_shortcut.dart';

/// The till's Enter chain has to fire on the FIRST press, on a popup stacked
/// over a page that is still mounted underneath. Both halves matter: a missed
/// press trains the operator to double-tap, and a page acting from underneath
/// charges a cart nobody is looking at.
void main() {
  testWidgets('fires on the first press, and only on the top route',
      (tester) async {
    var register = 0;
    var popup = 0;
    final nav = GlobalKey<NavigatorState>();

    await tester.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: EnterShortcut(
        onEnter: () => register++,
        child: const Scaffold(body: Text('register')),
      ),
    ));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(register, 1, reason: 'first press on the register');

    // Same shape as _dialogPage in router.dart: transparent, dismissible, so
    // the register stays mounted and visible below.
    nav.currentState!.push(PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => EnterShortcut(
        onEnter: () => popup++,
        child: const Center(child: Text('payment')),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(popup, 1, reason: 'first press on the popup');
    expect(register, 1, reason: 'the register must not act from underneath');

    // A held key repeats; completing the sale twice is not a feature.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
    expect(popup, 2);

    nav.currentState!.pop();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(register, 2, reason: 'register takes over once the popup is gone');
    expect(popup, 2);
  });

  // The real arrangement: a shell that owns a focus node above the branch
  // navigator, and the sale's popup pushed as a transparent route inside the
  // branch. This is what the plain-Navigator case above does not cover.
  testWidgets('fires first press through the shell and its popup route',
      (tester) async {
    var register = 0;
    var popup = 0;

    final router = GoRouter(
      initialLocation: '/pos',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) =>
              Focus(autofocus: true, child: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/pos',
                builder: (_, _) => EnterShortcut(
                  onEnter: () => register++,
                  child: const Scaffold(body: Text('register')),
                ),
              ),
              GoRoute(
                path: '/pay',
                pageBuilder: (_, state) => CustomTransitionPage<void>(
                  key: state.pageKey,
                  opaque: false,
                  barrierDismissible: true,
                  barrierColor: Colors.black54,
                  transitionDuration: const Duration(milliseconds: 200),
                  transitionsBuilder: (_, animation, _, child) =>
                      FadeTransition(opacity: animation, child: child),
                  child: EnterShortcut(
                    onEnter: () => popup++,
                    child: const Center(child: Text('payment')),
                  ),
                ),
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/other',
                builder: (_, _) => const Scaffold(body: Text('other module')),
              ),
            ]),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(register, 1);

    router.push('/pay');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(popup, 1, reason: 'first press on the payment popup');
    expect(register, 1, reason: 'the register must not push a second popup');

    // The register stays mounted in its branch when another module is shown;
    // its route is still "current" in that branch's own navigator.
    router.go('/other');
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(register, 1, reason: 'a hidden branch must not charge the cart');
    expect(popup, 1);
  });

  testWidgets('a null callback leaves Enter alone', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: EnterShortcut(onEnter: null, child: Scaffold(body: Text('x'))),
    ));
    // Nothing to assert but the absence of a crash and of a handled key: the
    // binding must not exist at all, so a focused button keeps Enter.
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.enter), isFalse);
  });
}
