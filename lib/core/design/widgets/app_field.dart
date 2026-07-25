import 'package:flutter/material.dart';
import '../app_colors.dart';
import '../app_spacing.dart';
import '../app_typography.dart';

/// The label above a field well. [isRequired] appends a red asterisk — the one
/// place that marking is defined, so every form spells "required" the same way.
class AppFieldLabel extends StatelessWidget {
  const AppFieldLabel(this.text, {super.key, this.isRequired = false});

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final style = AppTypography.fieldLabel.copyWith(color: lum.g700);
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: isRequired
          ? Text.rich(
              TextSpan(
                text: text,
                style: style,
                children: [
                  TextSpan(
                    text: ' *',
                    style: style.copyWith(color: lum.dangerText),
                  ),
                ],
              ),
              semanticsLabel: '$text, required',
            )
          : Text(text, style: style),
    );
  }
}

/// Fields packed onto one line, stacked instead when the row would squeeze
/// them under [minFieldWidth] (narrow windows, phones).
class AppFieldRow extends StatelessWidget {
  const AppFieldRow({super.key, required this.children, this.minFieldWidth = 190});

  final List<Widget> children;
  final double minFieldWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < minFieldWidth * children.length) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, w) in children.indexed) ...[
                if (i > 0) const SizedBox(height: AppSpacing.fieldGap),
                w,
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, w) in children.indexed) ...[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              Expanded(child: w),
            ],
          ],
        );
      },
    );
  }
}
