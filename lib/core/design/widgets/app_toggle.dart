import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_motion.dart';
import '../app_radius.dart';

/// The design system's pill switch: a 46x28 inset track that fills with Lumen
/// when on, carrying a 22px knob that springs across.
///
/// Material's [Switch] cannot express the inset track, so this is hand-rolled
/// rather than themed. The visual pill stays 46x28 while the tap target is
/// padded out to 44dp tall.
class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.semanticLabel,
  });

  final bool value;

  /// Null (or [enabled] false) renders the disabled treatment.
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final String? semanticLabel;

  static const _trackWidth = 46.0;
  static const _trackHeight = 28.0;
  static const _knob = 22.0;
  static const _inset = 3.0;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final live = enabled && onChanged != null;
    // Reduce-motion: the knob and fill snap instead of sliding.
    final duration =
        MediaQuery.disableAnimationsOf(context) ? Duration.zero : AppMotion.fast;

    final track = AnimatedContainer(
      duration: duration,
      curve: AppMotion.curve,
      width: _trackWidth,
      height: _trackHeight,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: value ? lum.accent : lum.surface2,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: lum.isDark ? 0.32 : 0.12),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: AnimatedAlign(
        duration: duration,
        curve: Curves.easeOutBack,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: _knob,
          height: _knob,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                offset: const Offset(0, 1),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      toggled: value,
      enabled: live,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: live ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: live ? 1 : 0.45,
          child: SizedBox(
            width: _trackWidth,
            height: 44,
            child: Center(child: track),
          ),
        ),
      ),
    );
  }
}
