import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_motion.dart';
import '../app_radius.dart';

/// Tints any card or button while the pointer is over it.
///
/// Painted as a translucent overlay rather than by swapping each surface's
/// colour, so it works over flat fills, gradients and clay shadows alike and
/// leaves every existing colour, size and shadow untouched. Touch platforms
/// never report hover, so this is inert there.
class AppHover extends StatefulWidget {
  const AppHover({
    super.key,
    required this.child,
    this.radius = AppRadius.lg,
    this.enabled = true,
    this.tint,
  });

  final Widget child;

  /// Corner radius of the overlay — match the wrapped surface's own radius.
  final double radius;

  /// False for locked/disabled surfaces, which should not react.
  final bool enabled;

  /// Overlay colour. Defaults to the neutral wash the nav rail hovers with
  /// (`lum.g100` over a surface), expressed as an alpha so it can sit on top.
  final Color? tint;

  @override
  State<AppHover> createState() => _AppHoverState();
}

class _AppHoverState extends State<AppHover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final lum = context.lum;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Stack(
        // Passthrough, not the default loose fit: a loose Stack would let the
        // wrapped card shrink to its content inside a tight grid cell, so the
        // filled overlay would spill past the card.
        fit: StackFit.passthrough,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _hovered ? 1 : 0,
                duration: AppMotion.fast,
                curve: AppMotion.curve,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.tint ??
                        (lum.isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : lum.ink.withValues(alpha: 0.055)),
                    borderRadius: BorderRadius.circular(widget.radius),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
