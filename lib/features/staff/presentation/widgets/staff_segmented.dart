import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_motion.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';

/// A pill segmented control (Roles / Members). Inset track with the active
/// segment lifted onto a soft-shadow surface pill — the design's tab switcher.
class StaffSegmented extends StatelessWidget {
  const StaffSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: lum.surface2,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                label: labels[i],
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    curve: AppMotion.curve,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == index ? lum.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      boxShadow: i == index
                          ? [
                              BoxShadow(
                                color: (lum.isDark ? Colors.black : Colors.black)
                                    .withValues(alpha: lum.isDark ? 0.4 : 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      labels[i],
                      style: AppTypography.label.copyWith(
                        color: i == index ? lum.accentPress : lum.g600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
