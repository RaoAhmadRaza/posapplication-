import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/widgets/module_scaffold.dart';
import '../../../../core/widgets/permission_gate.dart';

/// Purchasing landing menu — a launcher into every sub-area. Branch root, so no
/// back button (the nav rail is the way out).
class PurchaseHubPage extends StatelessWidget {
  const PurchaseHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final tiles = <_HubTileData>[
      _HubTileData(
        icon: LucideIcons.clipboardList,
        title: 'Purchase orders',
        description: 'Create, receive and track POs',
        tone: AppPillTone.lumen,
        onTap: () => context.push('/purchasing/orders'),
      ),
      _HubTileData(
        icon: LucideIcons.receiptText,
        title: 'Purchase invoices',
        description: '3-way match & bills',
        tone: AppPillTone.transit,
        onTap: () => context.push('/purchasing/invoices'),
      ),
      _HubTileData(
        icon: LucideIcons.wallet,
        title: 'Supplier payments',
        description: 'Record payments & credit',
        tone: AppPillTone.success,
        onTap: () => context.push('/purchasing/payments/create'),
      ),
      _HubTileData(
        icon: LucideIcons.refreshCcw,
        title: 'Reorder suggestions',
        description: 'Restock at or below reorder point',
        tone: AppPillTone.warning,
        onTap: () => context.push('/purchasing/reorder'),
      ),
      _HubTileData(
        icon: LucideIcons.undo2,
        title: 'Purchase returns',
        description: 'Debit notes to suppliers',
        tone: AppPillTone.danger,
        onTap: () => context.push('/purchasing/returns'),
      ),
      // The mock draws this disabled ('Soon'), but suppliers is a live feature
      // and a rail destination — shipped as a working tile.
      _HubTileData(
        icon: LucideIcons.truck,
        title: 'Suppliers',
        description: 'Directory & ledgers',
        tone: AppPillTone.neutral,
        onTap: () => context.go('/suppliers'),
      ),
    ];

    return ModuleScaffold(
      title: 'Purchasing',
      maxContentWidth: 1000,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 40),
      // Nav hides this module without purchase:read, but the route stays
      // reachable by deep link — gate the page too.
      child: PermissionGate(
        module: 'purchase',
        action: 'read',
        fallback: Center(
          child: Text(
            'You don’t have access to purchasing.',
            style: AppTypography.subhead.copyWith(color: lum.g500),
          ),
        ),
        child: SingleChildScrollView(
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth;
              final cols = w >= 820 ? 3 : (w >= 540 ? 2 : 1);
              const gap = 14.0;
              final tileW = (w - (cols - 1) * gap) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final t in tiles)
                    SizedBox(width: tileW, child: _HubTile(data: t)),
                ],
              );
            },
          ),
        ],
        ),
        ),
      ),
    );
  }
}

class _HubTileData {
  const _HubTileData({
    required this.icon,
    required this.title,
    required this.description,
    required this.tone,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final AppPillTone tone;
  final VoidCallback onTap;
}

class _HubTile extends StatelessWidget {
  const _HubTile({required this.data});

  final _HubTileData data;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (bg, fg) = switch (data.tone) {
      AppPillTone.neutral => (lum.g100, lum.g600),
      AppPillTone.lumen => (lum.accentSoft, lum.accentPress),
      AppPillTone.success => (lum.successSoft, lum.successText),
      AppPillTone.warning => (lum.warningSoft, lum.warningText),
      AppPillTone.danger => (lum.dangerSoft, lum.dangerText),
      AppPillTone.transit => (lum.transitSoft, lum.transitText),
    };

    return AppCard(
      onTap: data.onTap,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClayContainer(
                variant: ClayVariant.soft,
                color: bg,
                borderRadius: AppRadius.sm,
                isDark: lum.isDark,
                width: 44,
                height: 44,
                child: Center(child: Icon(data.icon, size: 21, color: fg)),
              ),
              const Spacer(),
              Icon(LucideIcons.chevronRight, size: 20, color: lum.g400),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            data.title,
            style: AppTypography.headline.copyWith(color: lum.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            data.description,
            style: AppTypography.footnote.copyWith(color: lum.g500),
          ),
        ],
      ),
    );
  }
}
