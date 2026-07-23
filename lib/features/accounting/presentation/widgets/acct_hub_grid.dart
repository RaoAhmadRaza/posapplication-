import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_card.dart';
import 'accounting_ui.dart';

/// One accounting-hub destination.
class AcctHubItem {
  const AcctHubItem({
    required this.icon,
    required this.label,
    required this.description,
    required this.iconBackground,
    required this.iconForeground,
    required this.onTap,
    this.external = false,
  });

  final IconData icon;
  final String label;
  final String description;
  final Color iconBackground;
  final Color iconForeground;
  final VoidCallback onTap;

  /// Renders the design's up-right cue instead of a chevron (opens elsewhere).
  final bool external;
}

/// The hub's responsive tile grid: two columns at the module-wide breakpoint,
/// one below. Width is derived from the constraints — never a fixed ratio.
class AcctHubGrid extends StatelessWidget {
  const AcctHubGrid({super.key, required this.items});

  final List<AcctHubItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final twoUp = constraints.maxWidth >= 560;
        // Roomier tiles on desktop so the hub doesn't read as empty.
        final big = constraints.maxWidth >= 720;
        final gap = big ? 16.0 : 12.0;
        final tileWidth =
            twoUp ? (constraints.maxWidth - gap) / 2 : constraints.maxWidth;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: tileWidth,
                child: _AcctHubTile(item: item, big: big),
              ),
          ],
        );
      },
    );
  }
}

class _AcctHubTile extends StatelessWidget {
  const _AcctHubTile({required this.item, required this.big});

  final AcctHubItem item;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: item.label,
      child: AppCard(
        onTap: item.onTap,
        padding: EdgeInsets.all(big ? 24 : 16),
        child: Row(
          children: [
            AcctIconTile(
              icon: item.icon,
              background: item.iconBackground,
              foreground: item.iconForeground,
              size: big ? 56 : 40,
              iconSize: big ? 27 : 20,
            ),
            SizedBox(width: big ? 18 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label,
                    style: AppTypography.headline.copyWith(
                      fontSize: big ? 18 : 15,
                      color: lum.textPrimary,
                    ),
                  ),
                  SizedBox(height: big ? 4 : 2),
                  Text(
                    item.description,
                    style: AppTypography.subhead.copyWith(
                      fontSize: big ? 14 : 12.5,
                      color: lum.g500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              item.external ? LucideIcons.arrowUpRight : LucideIcons.chevronRight,
              size: big ? 20 : 18,
              color: lum.g400,
            ),
          ],
        ),
      ),
    );
  }
}
