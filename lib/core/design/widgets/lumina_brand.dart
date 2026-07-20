import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../app_colors.dart';
import '../app_typography.dart';

/// The approved LUMINA logomark. Three SVG variants ship in assets/images;
/// [mono] picks the white-on-ink version for dark hero panels.
class LuminaGlyph extends StatelessWidget {
  const LuminaGlyph({
    super.key,
    this.size = 56,
    this.glow = false,
    this.mono = false,
  });

  final double size;
  final bool glow;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final asset = mono
        ? 'assets/images/lumina-glyph-mono-white.svg'
        : 'assets/images/lumina-glyph.svg';
    final img = SvgPicture.asset(asset, width: size, height: size);
    if (!glow) return img;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.accent.withValues(alpha: 0.45),
                    AppColors.accent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          img,
        ],
      ),
    );
  }
}

/// Wordmark — "LUMINA" in Clash Display + "POS" in accent.
class LuminaWordmark extends StatelessWidget {
  const LuminaWordmark({super.key, this.size = 24, this.color});

  final double size;

  /// Colour of the "LUMINA" part. "POS" always uses the accent.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: 'LUMINA', style: TextStyle(color: color ?? lum.ink)),
          TextSpan(
            text: ' POS',
            style: TextStyle(
              color: lum.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        style: TextStyle(
          fontFamily: AppTypography.display,
          fontSize: size,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1,
        ),
      ),
    );
  }
}
