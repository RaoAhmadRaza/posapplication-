import 'package:flutter/material.dart';

/// iOS claymorphism — the LUMINA surface language (`tokens/elevation.css`).
///
/// Flutter's [BoxShadow] cannot draw *inset* shadows, and the clay look is
/// built from inner highlights + inner shades. [ClayContainer] paints them
/// with a [CustomPainter]: outer ambient drops first, then the fill, then
/// inner shadows clipped to the rounded rect.
enum ClayVariant { raised, soft, inset, pressed, lumen }

@immutable
class _Shadow {
  const _Shadow(this.color, this.dx, this.dy, this.blur, {this.inner = false});
  final Color color;
  final double dx;
  final double dy;
  final double blur;
  final bool inner;
}

class ClayContainer extends StatelessWidget {
  const ClayContainer({
    super.key,
    required this.child,
    this.variant = ClayVariant.soft,
    this.color,
    this.borderRadius = 22,
    this.isDark = false,
    this.padding,
    this.width,
    this.height,
  });

  final Widget child;
  final ClayVariant variant;

  /// Fill colour. Null keeps the painter transparent (caller supplies its own
  /// gradient/fill, e.g. the Lumen gloss button).
  final Color? color;
  final double borderRadius;
  final bool isDark;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  List<_Shadow> get _shadows {
    final ink = isDark ? Colors.black : const Color(0xFF10131C);
    final hi = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
    switch (variant) {
      case ClayVariant.raised:
        return [
          _Shadow(ink.withValues(alpha: isDark ? 0.30 : 0.04), 0, 2, 4),
          _Shadow(ink.withValues(alpha: isDark ? 0.42 : 0.09), 0, 12, 28),
          _Shadow(hi.withValues(alpha: isDark ? 0.06 : 0.92), 0, 1.5, 1,
              inner: true),
          _Shadow(ink.withValues(alpha: isDark ? 0.40 : 0.045), 0, -2, 4,
              inner: true),
        ];
      case ClayVariant.soft:
        return [
          _Shadow(ink.withValues(alpha: isDark ? 0.28 : 0.04), 0, 1, 3),
          _Shadow(ink.withValues(alpha: isDark ? 0.36 : 0.07), 0, 6, 16),
          _Shadow(hi.withValues(alpha: isDark ? 0.05 : 0.85), 0, 1.5, 1,
              inner: true),
          _Shadow(ink.withValues(alpha: isDark ? 0.30 : 0.035), 0, -1.5, 3,
              inner: true),
        ];
      case ClayVariant.inset:
        return [
          _Shadow(ink.withValues(alpha: isDark ? 0.50 : 0.10), 0, 2, 5,
              inner: true),
          _Shadow(hi.withValues(alpha: isDark ? 0.05 : 0.60), 0, -1.5, 1,
              inner: true),
        ];
      case ClayVariant.pressed:
        return [
          _Shadow(ink.withValues(alpha: isDark ? 0.55 : 0.14), 0, 2, 6,
              inner: true),
          _Shadow(hi.withValues(alpha: isDark ? 0.04 : 0.50), 0, -1, 1,
              inner: true),
        ];
      case ClayVariant.lumen:
        const lumen = Color(0xFF2C6BFF);
        const press = Color(0xFF1A52E6);
        return [
          _Shadow(lumen.withValues(alpha: 0.36), 0, 6, 18),
          _Shadow(lumen.withValues(alpha: 0.24), 0, 2, 5),
          _Shadow(Colors.white.withValues(alpha: 0.50), 0, 1.5, 1,
              inner: true),
          _Shadow(press.withValues(alpha: 0.45), 0, -3, 6, inner: true),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ClayPainter(
        radius: borderRadius,
        fill: color,
        shadows: _shadows,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }
}

class _ClayPainter extends CustomPainter {
  _ClayPainter({required this.radius, required this.fill, required this.shadows});

  final double radius;
  final Color? fill;
  final List<_Shadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );

    // 1. Outer ambient drops (painted behind the fill).
    for (final s in shadows) {
      if (s.inner) continue;
      final paint = Paint()
        ..color = s.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur);
      canvas.drawRRect(rrect.shift(Offset(s.dx, s.dy)), paint);
    }

    // 2. Fill.
    if (fill != null) {
      canvas.drawRRect(rrect, Paint()..color = fill!);
    }

    // 3. Inner shadows — clip to the shape, draw an offset "hole" so the
    //    blurred bleed only shows on the inside edge.
    for (final s in shadows) {
      if (!s.inner) continue;
      canvas.save();
      canvas.clipRRect(rrect);
      final hole = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRRect(rrect.shift(Offset(s.dx, s.dy)));
      final paint = Paint()
        ..color = s.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s.blur);
      canvas.drawPath(hole, paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ClayPainter old) =>
      old.radius != radius || old.fill != fill || old.shadows != shadows;
}
