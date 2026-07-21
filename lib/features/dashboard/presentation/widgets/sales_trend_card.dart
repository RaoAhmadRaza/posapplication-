import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../domain/entities/dashboard_summary.dart';
import 'dashboard_section_card.dart';

/// Seven-day sales bars.
///
/// Hand-rolled rather than fl_chart: the design needs a per-bar entrance
/// stagger, a gloss fill on the latest bar only, and value labels above each
/// bar — all of which are plain widgets here, versus fighting chart config.
class SalesTrendCard extends StatelessWidget {
  const SalesTrendCard({super.key, required this.points});

  final List<TrendPoint> points;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final max = points.fold<double>(0, (m, p) => p.total > m ? p.total : m);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return DashboardSectionCard(
      title: 'Sales trend',
      eyebrow: 'LAST 7 DAYS',
      child: SizedBox(
        height: 152,
        child: max <= 0
            ? Center(
                child: Text(
                  'No sales in the last 7 days',
                  style: AppTypography.footnote.copyWith(color: lum.g500),
                ),
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < points.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: _Bar(
                        point: points[i],
                        fraction: points[i].total / max,
                        isLatest: i == points.length - 1,
                        delay: reduceMotion
                            ? Duration.zero
                            : Duration(milliseconds: 55 * i),
                        animate: !reduceMotion,
                        lum: lum,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.point,
    required this.fraction,
    required this.isLatest,
    required this.delay,
    required this.animate,
    required this.lum,
  });

  final TrendPoint point;
  final double fraction;
  final bool isLatest;
  final Duration delay;
  final bool animate;
  final LumColors lum;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      decoration: BoxDecoration(
        color: isLatest ? null : lum.accentSoft,
        gradient: isLatest
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [lum.accent, lum.accentPress],
              )
            : null,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
      ),
    );

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // The bar column is measured so the value label can sit directly on top
        // of the bar rather than floating at the top of the chart area.
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A hair of height so an empty day still reads as a bar.
              final barHeight =
                  constraints.maxHeight * fraction.clamp(0.02, 1.0);
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _abbreviate(point.total),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.clip,
                    style: AppTypography.monoValue.copyWith(
                      fontSize: 9.5,
                      color: lum.g500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: (barHeight - 18).clamp(2.0, constraints.maxHeight),
                    child: animate ? _GrowIn(delay: delay, child: bar) : bar,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _weekday(point.day),
          maxLines: 1,
          style: AppTypography.caption.copyWith(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: lum.g500,
          ),
        ),
      ],
    );
  }

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  static String _weekday(DateTime d) => _days[(d.weekday - 1) % 7];

  /// Compact bar label: 1.2m / 284k / 940.
  static String _abbreviate(double v) {
    final abs = v.abs();
    if (abs >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}m';
    if (abs >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

/// Scales a bar up from its base, after an optional stagger delay.
class _GrowIn extends StatefulWidget {
  const _GrowIn({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_GrowIn> createState() => _GrowInState();
}

class _GrowInState extends State<_GrowIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      alignment: Alignment.bottomCenter,
      child: widget.child,
    );
  }
}
