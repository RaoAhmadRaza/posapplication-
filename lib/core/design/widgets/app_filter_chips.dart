import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_haptics.dart';
import '../app_radius.dart';
import '../app_typography.dart';

/// Horizontally scrolling row of pill filters (POS categories, invoice status).
///
/// Selection is index-based against [labels]; the caller owns the state.
class AppFilterChips extends StatelessWidget {
  const AppFilterChips({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
    this.height = 34,
    this.padding = EdgeInsets.zero,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;
  final double height;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: labels.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, i) => AppFilterChip(
          label: labels[i],
          active: i == selected,
          onTap: () => onSelected(i),
        ),
      ),
    );
  }
}

/// A single filter pill. Exposed so a caller can lay chips out itself (e.g. in
/// a [Wrap]) while keeping the same look.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: Material(
        color: active ? lum.accentSoft : lum.g100,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: () {
            AppHaptics.selection();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: AppTypography.footnote.copyWith(
                  fontWeight: FontWeight.w600,
                  color: active ? lum.accentPress : lum.g600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
