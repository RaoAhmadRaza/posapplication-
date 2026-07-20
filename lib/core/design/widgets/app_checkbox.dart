import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_motion.dart';
import '../app_typography.dart';
import '../clay.dart';

/// Clay checkbox — Lumen gloss when checked, inset well when not.
class AppCheckbox extends StatelessWidget {
  const AppCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      checked: value,
      label: label,
      child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppMotion.fast,
            curve: AppMotion.curve,
            width: 20,
            height: 20,
            child: value
                ? ClayContainer(
                    variant: ClayVariant.lumen,
                    color: lum.accent,
                    borderRadius: 6,
                    isDark: lum.isDark,
                    child: const Center(
                      child: Icon(Icons.check, size: 13, color: Colors.white),
                    ),
                  )
                : ClayContainer(
                    variant: ClayVariant.inset,
                    color: lum.surface2,
                    borderRadius: 6,
                    isDark: lum.isDark,
                    child: const SizedBox.shrink(),
                  ),
          ),
          if (label != null) ...[
            const SizedBox(width: 10),
            Text(
              label!,
              style: AppTypography.label.copyWith(
                color: lum.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    ),
    );
  }
}
