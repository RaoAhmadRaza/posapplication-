import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/widgets/module_scaffold.dart';

/// Inventory landing menu — a launcher into every sub-area. Branch root, so no
/// back button (the nav rail / bottom bar is the way out). Two groups mirror the
/// design: Catalog and Stock. Sublabels are static descriptors — the hub loads
/// no data, so it never shows a fabricated count.
class InventoryHubPage extends StatelessWidget {
  const InventoryHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;

    const groups = <_HubGroup>[
      _HubGroup('Catalog', [
        _HubTileData(LucideIcons.boxes, 'Products',
            'Browse, search and manage products', '/inventory/products'),
        _HubTileData(LucideIcons.scanLine, 'Barcode templates',
            'Label layouts for printing', '/inventory/barcode-templates'),
        _HubTileData(LucideIcons.folderTree, 'Categories',
            'Organize products by category', '/inventory/categories'),
        _HubTileData(LucideIcons.tag, 'Brands', 'Manage product brands',
            '/inventory/brands'),
      ]),
      _HubGroup('Stock', [
        _HubTileData(LucideIcons.warehouse, 'Warehouses',
            'Stock locations per branch', '/inventory/warehouses'),
        _HubTileData(LucideIcons.layers, 'Stock levels',
            'On-hand by product and location', '/inventory/stock'),
        _HubTileData(LucideIcons.slidersHorizontal, 'Adjustments',
            'Damage, theft, write-offs, recounts', '/inventory/adjustments'),
        _HubTileData(LucideIcons.arrowLeftRight, 'Transfers',
            'Move stock between branches', '/inventory/transfers'),
        _HubTileData(LucideIcons.clipboardCheck, 'Stock counts',
            'Physical inventory audits', '/inventory/counts'),
        _HubTileData(LucideIcons.searchCode, 'IMEI lookup',
            'Search and track serialized items', '/inventory/imei'),
      ]),
    ];

    return ModuleScaffold(
      title: 'Inventory',
      maxContentWidth: 940,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
      child: SingleChildScrollView(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'One light. Every operation.',
            style: AppTypography.subhead.copyWith(color: lum.g500),
          ),
          const SizedBox(height: 20),
          for (final g in groups) ...[
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 12),
              child: Text(
                g.label.toUpperCase(),
                style: AppTypography.caption.copyWith(
                  color: lum.textTertiary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                final cols = w >= 700 ? 2 : 1;
                const gap = 12.0;
                final tileW = (w - (cols - 1) * gap) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final t in g.tiles)
                      SizedBox(width: tileW, child: _HubTile(data: t)),
                  ],
                );
              },
            ),
            const SizedBox(height: 26),
          ],
        ],
        ),
      ),
    );
  }
}

class _HubGroup {
  const _HubGroup(this.label, this.tiles);
  final String label;
  final List<_HubTileData> tiles;
}

class _HubTileData {
  const _HubTileData(this.icon, this.title, this.description, this.route);
  final IconData icon;
  final String title;
  final String description;
  final String route;
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.data});
  final _HubTileData data;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return AppCard(
      onTap: () => context.push(data.route),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accentSoft,
            borderRadius: AppRadius.sm,
            isDark: lum.isDark,
            width: 44,
            height: 44,
            child: Center(
              child: Icon(data.icon, size: 21, color: lum.accent),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: AppTypography.headline.copyWith(color: lum.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  data.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.footnote.copyWith(color: lum.g500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(LucideIcons.chevronRight, size: 18, color: lum.g400),
        ],
      ),
    );
  }
}
