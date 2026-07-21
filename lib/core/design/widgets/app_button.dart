import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_haptics.dart';
import '../app_motion.dart';
import '../app_radius.dart';
import '../app_typography.dart';
import '../clay.dart';

/// Variants map to the design's Button component:
///   filled → Lumen gloss pill (clay-lumen)
///   tinted → ghost (accent-soft fill, accent text)
///   plain  → transparent, accent text
///   destructive → danger-soft fill, danger text
enum AppButtonVariant { filled, tinted, plain, destructive }

/// Height of the button. [md] is the standard 50px form button; [sm] is the
/// design's compact toolbar button (Workload / History / New job).
enum AppButtonSize {
  md(50, 15, 18, 22),
  sm(38, 13.5, 16, 14);

  const AppButtonSize(this.height, this.fontSize, this.iconSize, this.gutter);

  final double height;
  final double fontSize;
  final double iconSize;
  final double gutter;
}

class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.filled,
    this.loading = false,
    this.fullWidth = false,
    this.icon,
    this.size = AppButtonSize.md,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool loading;
  final bool fullWidth;
  final IconData? icon;
  final AppButtonSize size;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final variant = widget.variant;
    final isFilled = variant == AppButtonVariant.filled;

    final (Color bg, Color fg) = switch (variant) {
      AppButtonVariant.filled => (lum.accent, Colors.white),
      AppButtonVariant.destructive => (lum.dangerSoft, lum.dangerText),
      AppButtonVariant.tinted => (lum.accentSoft, lum.accent),
      AppButtonVariant.plain => (Colors.transparent, lum.accent),
    };

    final size = widget.size;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: size.iconSize,
            height: size.iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, color: fg, size: size.iconSize),
            SizedBox(width: size == AppButtonSize.sm ? 7 : 9),
          ],
          Text(
            widget.label,
            style:
                AppTypography.label.copyWith(color: fg, fontSize: size.fontSize),
          ),
        ],
      ],
    );

    // Plain/tinted use a simple fill; filled uses the clay Lumen gloss.
    Widget surface;
    if (isFilled) {
      surface = ClayContainer(
        variant: _pressed ? ClayVariant.pressed : ClayVariant.lumen,
        color: _pressed ? lum.accentPress : lum.accent,
        borderRadius: AppRadius.sm,
        isDark: lum.isDark,
        height: size.height,
        width: widget.fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: size.gutter),
        child: Center(child: content),
      );
    } else {
      surface = Container(
        height: size.height,
        width: widget.fullWidth ? double.infinity : null,
        padding: EdgeInsets.symmetric(horizontal: size.gutter),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: variant == AppButtonVariant.plain && _pressed
              ? lum.accentSoft
              : bg,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: content,
      );
    }

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.loading ? '${widget.label}, loading' : widget.label,
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
        onTap: _enabled
            ? () {
                AppHaptics.selection();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          child: AnimatedOpacity(
            opacity: _enabled ? 1.0 : 0.5,
            duration: AppMotion.fast,
            child: surface,
          ),
        ),
      ),
    );
  }
}
