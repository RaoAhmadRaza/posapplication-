import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../app_colors.dart';
import '../app_haptics.dart';
import '../app_radius.dart';
import '../app_typography.dart';
import '../clay.dart';

/// Inset `−  n  +` pill used wherever a line quantity is edited (cart lines,
/// return lines).
///
/// The value is clamped to [min]..[max]; a button that would leave the range is
/// dimmed and inert rather than hidden, so the control never changes width.
class AppQtyStepper extends StatelessWidget {
  const AppQtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max,
    this.enabled = true,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int? max;

  /// Dims the whole control and blocks both buttons (e.g. an unselected return
  /// line).
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final canDec = enabled && value > min;
    final canInc = enabled && (max == null || value < max!);

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: ClayContainer(
        variant: ClayVariant.inset,
        color: lum.surface2,
        borderRadius: AppRadius.pill,
        isDark: lum.isDark,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StepButton(
              icon: LucideIcons.minus,
              enabled: canDec,
              raised: false,
              onTap: () => onChanged(value - 1),
              semanticLabel: 'Decrease quantity',
            ),
            SizedBox(
              width: 30,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: AppTypography.monoValue.copyWith(
                  fontWeight: FontWeight.w600,
                  color: lum.textPrimary,
                ),
              ),
            ),
            _StepButton(
              icon: LucideIcons.plus,
              enabled: canInc,
              raised: true,
              onTap: () => onChanged(value + 1),
              semanticLabel: 'Increase quantity',
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.raised,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final bool enabled;

  /// The plus button sits proud of the well; the minus button is flush.
  final bool raised;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final color = enabled
        ? (raised ? lum.accent : lum.g600)
        : lum.textDisabled;

    final glyph = SizedBox(
      width: 26,
      height: 26,
      child: Icon(icon, size: 16, color: color),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: InkWell(
        onTap: enabled
            ? () {
                AppHaptics.selection();
                onTap();
              }
            : null,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: raised && enabled
            ? ClayContainer(
                variant: ClayVariant.soft,
                color: lum.surface,
                borderRadius: AppRadius.pill,
                isDark: lum.isDark,
                width: 26,
                height: 26,
                child: Icon(icon, size: 16, color: color),
              )
            : glyph,
      ),
    );
  }
}
