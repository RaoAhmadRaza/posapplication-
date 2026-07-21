import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../app_colors.dart';
import '../app_radius.dart';
import '../app_typography.dart';
import 'app_card.dart';

/// Icon-tile treatment on an [AppSettingsRow].
enum AppSettingsRowTone { neutral, lumen }

/// The design's universal settings row: a rounded icon tile, a title over a
/// subtitle, an optional trailing control or meta label, and a chevron when the
/// row navigates.
///
/// Shared by the settings hub, the profile screen and the payment-method cards,
/// so it lives in the design system rather than in one feature.
class AppSettingsRow extends StatelessWidget {
  const AppSettingsRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.tone = AppSettingsRowTone.neutral,
    this.meta,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final AppSettingsRowTone tone;

  /// Small right-aligned label before the chevron (e.g. a status pill).
  final Widget? meta;

  /// Control replacing the chevron (e.g. an [AppToggle]).
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final lumen = tone == AppSettingsRowTone.lumen;

    final row = Padding(
      padding: padding,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: lumen ? lum.accentSoft : lum.g100,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              icon,
              size: 20,
              color: lumen ? lum.accent : lum.g600,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTypography.body.copyWith(
                    fontWeight: FontWeight.w600,
                    color: lum.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: AppTypography.footnote.copyWith(color: lum.g500),
                  ),
                ],
              ],
            ),
          ),
          if (meta != null) ...[const SizedBox(width: 12), meta!],
          if (trailing != null)
            ...[const SizedBox(width: 12), trailing!]
          else if (onTap != null) ...[
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 20, color: lum.g300),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

/// Uppercase group label over a clay card of hairline-separated rows — the
/// design's settings-list grouping.
class AppSettingsGroup extends StatelessWidget {
  const AppSettingsGroup({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(
              title!.toUpperCase(),
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
                color: lum.g400,
              ),
            ),
          ),
        AppCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: lum.hairline),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
