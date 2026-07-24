import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_spacing.dart';

/// Shimmering card-row placeholders shown while a list screen loads, replacing
/// a bare spinner. One repeating controller sweeps a highlight across all rows.
/// Respects reduce-motion (static soft blocks, no sweep).
class AppListSkeleton extends StatefulWidget {
  const AppListSkeleton({super.key, this.rows = 4, this.rowHeight = 92});

  final int rows;
  final double rowHeight;

  @override
  State<AppListSkeleton> createState() => _AppListSkeletonState();
}

class _AppListSkeletonState extends State<AppListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final base = lum.isDark
        ? Colors.white.withValues(alpha: 0.05)
        : const Color(0xFF10131C).withValues(alpha: 0.05);
    final highlight = lum.isDark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.65);

    // Clip rather than overflow: placed inside a bounded Expanded on list
    // screens, the fixed-height rows can exceed a short viewport. Non-scrolling
    // so it still reads as a static placeholder.
    final rows = SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: List.generate(
          widget.rows,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Container(
              height: widget.rowHeight,
              decoration: BoxDecoration(
                color: base,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ),
      ),
    );

    if (MediaQuery.of(context).disableAnimations) return rows;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [base, highlight, base],
          stops: const [0.35, 0.5, 0.65],
          transform: _SlideGradient(rect.width * (_c.value * 2 - 1)),
        ).createShader(rect),
        child: child,
      ),
      child: rows,
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.dx);
  final double dx;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(dx, 0, 0);
}
