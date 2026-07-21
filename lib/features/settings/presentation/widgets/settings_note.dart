import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';

/// The design's quiet explanatory note: an info glyph beside a sentence on a
/// tinted well. Neutral by default; [lumen] tints it accent for the
/// "you can view but not change this" case.
class SettingsNote extends StatelessWidget {
  const SettingsNote(this.message, {super.key, this.lumen = false});

  final String message;
  final bool lumen;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final bg = lumen ? lum.accentSoft : lum.g100;
    final fg = lumen ? lum.accentPress : lum.g500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(LucideIcons.info, size: 18, color: fg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.footnote.copyWith(color: fg, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
