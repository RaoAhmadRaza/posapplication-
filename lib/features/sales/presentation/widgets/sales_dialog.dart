import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';

/// Centred card the sale's steps render in — payment, sale complete and receipt
/// sit over the register instead of replacing it, so the counter never loses
/// sight of the cart mid-sale. Same frame as the hold-sale dialog.
///
/// These are routes, not `showDialog` calls (see `_dialogPage` in router.dart),
/// so every existing path/extra and the Enter flow work unchanged.
class SalesDialog extends StatelessWidget {
  const SalesDialog({
    super.key,
    required this.title,
    required this.child,
    this.bottomBar,
    this.onClose,
    this.maxWidth = 560,
  });

  final String title;
  final Widget child;

  /// Pinned under the body, above a hairline (e.g. Complete sale).
  final Widget? bottomBar;

  /// Null hides the close control — used while a sale is being submitted.
  final VoidCallback? onClose;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final size = MediaQuery.sizeOf(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            // Long carts scroll inside the card rather than growing it off
            // the top and bottom of a short window.
            maxHeight: size.height * 0.9,
          ),
          child: ClayContainer(
            variant: ClayVariant.raised,
            color: lum.surface,
            borderRadius: AppRadius.xl,
            isDark: lum.isDark,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 12, 16),
                  child: Row(
                    children: [
                      Expanded(child: Text(title, style: AppTypography.title3)),
                      if (onClose != null)
                        Semantics(
                          button: true,
                          label: 'Close',
                          child: InkWell(
                            onTap: onClose,
                            borderRadius:
                                BorderRadius.circular(AppRadius.pill),
                            child: SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(
                                LucideIcons.x,
                                size: 18,
                                color: lum.g500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(height: 1, color: lum.hairline),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                    child: child,
                  ),
                ),
                if (bottomBar != null) ...[
                  Container(height: 1, color: lum.hairline),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: bottomBar,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
