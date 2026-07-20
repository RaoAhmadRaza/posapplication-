import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_motion.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/lumina_brand.dart';
import '../../../../core/state/app_flow_state.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  Timer? _handoff;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.slow,
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: AppMotion.curve),
    );
    _controller.forward();
    // Brief brand moment, then let the router advance to the env-check gate.
    _handoff = Timer(
      const Duration(milliseconds: 1600),
      () => SplashState.instance.shown = true,
    );
  }

  @override
  void dispose() {
    _handoff?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Splash is always the LUMINA "ink" hero panel regardless of theme, so the
    // dark #10131C background + aurora glow + white wordmark are hardcoded here
    // (brand hero, not a themed surface).
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.6, -0.9),
            radius: 1.2,
            colors: [Color(0x382C6BFF), AppColors.ink],
            stops: [0.0, 0.6],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LuminaGlyph(size: 80, glow: true),
                const SizedBox(height: AppSpacing.xl),
                const LuminaWordmark(size: 32, color: Colors.white),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'One light. Every operation.',
                  style: AppTypography.subhead.copyWith(
                    color: const Color(0xFFA9AFC2),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.accent.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
