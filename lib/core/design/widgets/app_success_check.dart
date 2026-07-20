import 'package:flutter/material.dart';

/// Success checkmark that pops in with an elastic scale. Reused wherever a
/// success is acknowledged (toast, reset / pin-setup / mfa-enroll flows).
/// Falls back to a static icon when the OS has reduce-motion enabled.
class AppSuccessCheck extends StatelessWidget {
  const AppSuccessCheck({super.key, required this.color, this.size = 18});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.check_circle, color: color, size: size);
    if (MediaQuery.of(context).disableAnimations) return icon;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.elasticOut,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: icon,
    );
  }
}
