import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_motion.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';

/// A selectable option card (role picker, change-role radio). Lumen ring + soft
/// fill when selected, hairline border otherwise — matches the design export's
/// bordered option tiles. Optionally shows a radio dot or a trailing label.
class StaffOptionCard extends StatelessWidget {
  const StaffOptionCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailingText,
    this.showRadio = false,
  });

  final String title;
  final String? subtitle;
  final String? trailingText;
  final bool showRadio;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? lum.accentSoft : lum.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: selected ? lum.accent : lum.hairline,
              width: 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: lum.accentSoft,
                      blurRadius: 0,
                      spreadRadius: 3,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.label.copyWith(
                        color: selected ? lum.accentPress : lum.textPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: AppTypography.footnote.copyWith(color: lum.g500),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailingText != null) ...[
                const SizedBox(width: 10),
                Text(
                  trailingText!,
                  style: AppTypography.caption.copyWith(color: lum.g500),
                ),
              ],
              if (showRadio) ...[
                const SizedBox(width: 12),
                _Radio(selected: selected),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? lum.accent : lum.surface2,
        border: Border.all(
          color: selected ? lum.accent : lum.hairline,
          width: 1.5,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            )
          : null,
    );
  }
}
