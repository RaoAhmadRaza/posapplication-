import 'package:flutter/material.dart';
import '../../../../core/design/widgets/app_settings_row.dart';

/// A single tappable settings row. Thin wrapper over the design system's
/// [AppSettingsRow] so the hub's call sites keep their original signature.
///
/// [showDivider] is retained for compatibility but no longer draws anything —
/// [AppSettingsGroup] separates its own rows, which is what keeps a group's
/// first row free of a stray rule.
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
    this.tone = AppSettingsRowTone.neutral,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;
  final AppSettingsRowTone tone;

  @override
  Widget build(BuildContext context) => AppSettingsRow(
        icon: icon,
        title: title,
        subtitle: subtitle,
        tone: tone,
        onTap: onTap,
      );
}
