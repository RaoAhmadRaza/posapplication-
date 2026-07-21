import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../auth/presentation/controllers/permission_controller.dart';

/// One quick-launch target and the permission that unlocks it.
class _Action {
  const _Action(this.label, this.icon, this.permission, this.onTap,
      {this.primary = false});

  final String label;
  final IconData icon;
  final String permission;
  final void Function(BuildContext) onTap;

  /// POS is the accented tile; the rest are neutral.
  final bool primary;
}

/// Shortcut grid. Tiles the user lacks permission for stay visible but locked,
/// so the app's shape is discoverable rather than silently different per role.
class QuickLaunch extends ConsumerWidget {
  const QuickLaunch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final matrix = ref.watch(permissionMatrixProvider).value ?? <String>{};

    // Nav verbs differ deliberately: POS and Inventory are shell branches
    // (go), history and reports are pushed on top of the current branch.
    final actions = <_Action>[
      _Action('POS', LucideIcons.scanLine, 'sales:create',
          (c) => c.go('/sales/pos'),
          primary: true),
      _Action('Inventory', LucideIcons.warehouse, 'inventory:read',
          (c) => c.go('/inventory')),
      _Action('Sales history', LucideIcons.history, 'sales:read',
          (c) => c.push('/sales/history')),
      _Action('Reports', LucideIcons.barChart3, 'reports:read',
          (c) => c.push('/reports')),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 4, 2, 10),
          child: Text(
            'Quick launch',
            style: AppTypography.title3.copyWith(
              fontSize: 16,
              color: lum.textPrimary,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final a in actions)
              _QuickTile(
                action: a,
                allowed: matrix.contains(a.permission),
              ),
          ],
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.action, required this.allowed});

  final _Action action;
  final bool allowed;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final chipBg = !allowed
        ? lum.surface2
        : (action.primary ? lum.accentSoft : lum.surface2);
    final chipFg = !allowed
        ? lum.g400
        : (action.primary ? lum.accent : lum.g600);

    final tile = Opacity(
      opacity: allowed ? 1 : 0.6,
      child: ClayContainer(
        variant: allowed ? ClayVariant.soft : ClayVariant.inset,
        color: lum.surface,
        borderRadius: AppRadius.lg,
        isDark: lum.isDark,
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(action.icon, size: 20, color: chipFg),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    action.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(
                      fontSize: 13.5,
                      color: lum.textPrimary,
                    ),
                  ),
                  if (!allowed) ...[
                    const SizedBox(height: 1),
                    Text(
                      'No access',
                      style: AppTypography.caption.copyWith(
                        fontSize: 11,
                        color: lum.g500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!allowed) {
      return Semantics(
        button: true,
        enabled: false,
        label: '${action.label}, no access',
        child: tile,
      );
    }

    return Semantics(
      button: true,
      label: action.label,
      child: InkWell(
        onTap: () => action.onTap(context),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: tile,
      ),
    );
  }
}
