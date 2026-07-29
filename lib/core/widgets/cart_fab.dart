import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../features/sales/presentation/controllers/pos_cart_controller.dart';
import '../../router.dart';
import '../design/app_colors.dart';

/// Screens that already put the cart on screen, where the button is redundant.
const _hiddenOn = ['/sales/pos', '/sales/payment'];

/// Whether the floating cart button belongs on screen for [count] cart items at
/// [path].
bool showCartFab(int count, String path) =>
    count > 0 && !_hiddenOn.any(path.startsWith);

/// App-wide floating cart button: appears the moment the POS cart holds a line
/// (scan included) and disappears when it empties. Mounted from
/// [MaterialApp.router]'s builder so one instance covers every route instead of
/// each page growing its own.
class GlobalCartFab extends ConsumerWidget {
  const GlobalCartFab({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(posCartProvider.select((c) => c.totalItems));
    // ponytail: fixed clearance for the mobile bottom bar (~62px). Full-screen
    // pages below the breakpoint float it that bit high; measure the bar if that
    // ever reads wrong.
    final barClearance = MediaQuery.sizeOf(context).width < 900 ? 62.0 : 0.0;

    return Stack(
      children: [
        child,
        Positioned(
          right: 16,
          bottom: 16 + barClearance + MediaQuery.viewPaddingOf(context).bottom,
          child: ListenableBuilder(
            listenable: appRouter.routerDelegate,
            builder: (context, _) {
              // `.uri` off the match list, not `GoRouter.state`: the latter reads
              // `matches.last` and throws on the empty config the delegate holds
              // before the first route resolves.
              final path =
                  appRouter.routerDelegate.currentConfiguration.uri.path;
              if (!showCartFab(count, path)) return const SizedBox.shrink();
              return Semantics(
                button: true,
                label: 'View cart, $count items',
                child: Badge(
                  label: Text('$count'),
                  offset: const Offset(-2, 2),
                  child: FloatingActionButton(
                    // Null tag: a page with its own FAB would otherwise crash on
                    // a duplicate hero tag.
                    heroTag: null,
                    backgroundColor: context.lum.accent,
                    foregroundColor: Colors.white,
                    // No `tooltip:` — it builds an OverlayPortal, and this widget
                    // is mounted above the Navigator, so there is no Overlay in
                    // scope. Semantics carries the label instead.
                    onPressed: () => appRouter.go('/sales/pos'),
                    child: const Icon(LucideIcons.shoppingCart),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
