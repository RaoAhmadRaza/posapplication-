import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../state/theme_controller.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_typography.dart';
import '../clay.dart';
import 'lumina_brand.dart';

/// Raised clay card holding a titled auth form. Pair with [AuthHeroScaffold]:
/// `AuthHeroScaffold(child: AuthFormCard(title: ..., children: [...]))`.
class AuthFormCard extends StatelessWidget {
  const AuthFormCard({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ClayContainer(
      variant: ClayVariant.raised,
      color: lum.surface,
      borderRadius: AppRadius.xl,
      isDark: lum.isDark,
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: AppTypography.largeTitle.copyWith(color: lum.textPrimary),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              subtitle!,
              style: AppTypography.subhead.copyWith(color: lum.textSecondary),
            ),
          ],
          const SizedBox(height: 24),
          ...children,
          if (footer != null) ...[
            const SizedBox(height: 20),
            footer!,
          ],
        ],
      ),
    );
  }
}

/// Responsive auth shell matching the design's Login layout:
///   desktop (≥ 900px) → two columns: ink Prism hero (44%) + paper form (56%)
///   mobile            → stacked: glyph + wordmark, then the form card
///
/// [child] is the form card the caller builds. The hero copy is fixed brand
/// messaging ("One light. Every operation.").
class AuthHeroScaffold extends StatelessWidget {
  const AuthHeroScaffold({super.key, required this.child});

  final Widget child;

  // Below this width we drop the ink hero and center a single column so the
  // card never hugs an edge on mid-size desktop windows.
  static const _breakpoint = 1024.0;
  static const _version = 'v1.0.0 · © Stock Bridge';

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Scaffold(
      backgroundColor: lum.paper,
      body: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= _breakpoint) {
            return Row(
              children: [
                const Expanded(flex: 44, child: _PrismHero()),
                Expanded(flex: 56, child: _FormSide(child: child)),
              ],
            );
          }
          return SafeArea(
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: c.maxHeight - 1),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const LuminaGlyph(size: 56),
                              const SizedBox(height: 12),
                              const LuminaWordmark(size: 22),
                              const SizedBox(height: 24),
                              child,
                              const SizedBox(height: 20),
                              Text(
                                _version,
                                style: AppTypography.caption
                                    .copyWith(color: lum.textTertiary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                _ThemeToggle(lum: lum),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _FormSide extends StatelessWidget {
  const _FormSide({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return ColoredBox(
      color: lum.paper,
      child: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: child,
                ),
              ),
            ),
          ),
          _ThemeToggle(lum: lum),
        ],
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.lum});
  final LumColors lum;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 6,
      right: 8,
      child: IconButton(
        tooltip: 'Toggle theme',
        onPressed: ThemeController.toggle,
        icon: Icon(
          lum.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          color: lum.textTertiary,
          size: 20,
        ),
      ),
    );
  }
}

/// Ink hero panel — breathing aurora glow, faint prism rays, gradient headline.
class _PrismHero extends StatefulWidget {
  const _PrismHero();

  @override
  State<_PrismHero> createState() => _PrismHeroState();
}

class _PrismHeroState extends State<_PrismHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.of(context).disableAnimations;
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0xFF10131C)),
        // Blue aurora glow drifting in from the top-right.
        _AuroraGlow(
          anim: _breath,
          reduce: reduce,
          top: -160,
          right: -140,
          size: 620,
          color: const Color(0xFF2C6BFF),
          baseOpacity: 0.28,
          invert: false,
        ),
        // Faint warm beam glow, bottom-left (breathes opposite phase).
        _AuroraGlow(
          anim: _breath,
          reduce: reduce,
          bottom: -180,
          left: -160,
          size: 560,
          color: const Color(0xFFFF9F45),
          baseOpacity: 0.14,
          invert: true,
        ),
        CustomPaint(painter: _RaysPainter(), size: Size.infinite),
        Padding(
          padding: const EdgeInsets.all(56),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  LuminaGlyph(size: 48),
                  SizedBox(width: 14),
                  LuminaWordmark(size: 24, color: Colors.white),
                ],
              ),
              const Spacer(),
              ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFF5B7FFF), Color(0xFF00D4FF), Color(0xFFFF9F45)],
                  stops: [0.0, 0.55, 1.0],
                ).createShader(r),
                child: const Text(
                  'One light.\nEvery operation.',
                  style: TextStyle(
                    fontFamily: AppTypography.display,
                    fontWeight: FontWeight.w600,
                    fontSize: 46,
                    height: 1.05,
                    letterSpacing: -1.4,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const SizedBox(
                width: 340,
                child: Text(
                  'The retail ERP that works offline. Sign in to open the counter.',
                  style: TextStyle(
                    fontFamily: AppTypography.ui,
                    fontSize: 16,
                    height: 1.55,
                    color: Color(0xFFA9AFC2),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                AuthHeroScaffold._version,
                style: const TextStyle(
                  fontFamily: AppTypography.ui,
                  fontSize: 12,
                  color: Color(0xFF67635A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Positions a [_Glow] and breathes its opacity + scale off [anim]. When
/// [reduce] (OS reduce-motion) it renders the static glow at [baseOpacity].
class _AuroraGlow extends StatelessWidget {
  const _AuroraGlow({
    required this.anim,
    required this.reduce,
    required this.size,
    required this.color,
    required this.baseOpacity,
    required this.invert,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  final Animation<double> anim;
  final bool reduce;
  final double size;
  final Color color;
  final double baseOpacity;
  final bool invert;
  final double? top, bottom, left, right;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: reduce
          ? _Glow(size: size, color: color, opacity: baseOpacity)
          : AnimatedBuilder(
              animation: anim,
              builder: (context, child) {
                final t = invert ? 1 - anim.value : anim.value;
                return Transform.scale(
                  scale: 0.92 + 0.08 * t,
                  child: _Glow(
                    size: size,
                    color: color,
                    opacity: baseOpacity * (0.7 + 0.3 * t),
                  ),
                );
              },
            ),
    );
  }
}

/// Soft circular aurora glow used behind the ink hero panel.
class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color, required this.opacity});

  final double size;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.7],
          ),
        ),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width * 0.5, size.height * 0.38);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 0; i < 6; i++) {
      final a = (30 + i * 14) * math.pi / 180;
      canvas.drawLine(
        origin,
        origin + Offset(math.cos(a), math.sin(a)) * 900,
        paint,
      );
    }
    // faint refracted shard
    final shard = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.08);
    final p = Path()
      ..moveTo(size.width * 0.5, size.height * 0.2)
      ..lineTo(size.width * 0.78, size.height * 0.6)
      ..lineTo(size.width * 0.22, size.height * 0.6)
      ..close();
    canvas.drawPath(p, shard);
  }

  @override
  bool shouldRepaint(_RaysPainter oldDelegate) => false;
}
