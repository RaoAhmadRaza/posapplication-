import 'package:flutter/material.dart';

/// The design's `lum-rise` entrance: fade in while sliding up 14px.
///
/// Falls back to a static child when the OS asks for reduced motion.
class SalesRise extends StatefulWidget {
  const SalesRise({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 400),
  });

  final Widget child;
  final Duration duration;

  @override
  State<SalesRise> createState() => _SalesRiseState();
}

class _SalesRiseState extends State<SalesRise>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (!_controller.isAnimating && _controller.value == 0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 14 * (1 - _curve.value)),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}
