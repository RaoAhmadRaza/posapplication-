import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/staff_entities.dart';

/// One role in the roles list: an icon tile, the name with a System badge for
/// immutable roles, the level + description, and the perms/users counts. System
/// roles are not tappable (the backing RPC rejects editing them), so [onTap] is
/// null for those.
class StaffRoleCard extends StatelessWidget {
  const StaffRoleCard({super.key, required this.role, this.onTap});

  final TenantRole role;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final editable = !role.isSystemRole;
    final desc = role.description?.trim();
    final sub = 'Level ${role.hierarchyLevel}'
        '${desc != null && desc.isNotEmpty ? ' · $desc' : ''}';
    final counts =
        '${role.permissionCount} perm${role.permissionCount == 1 ? '' : 's'} · '
        '${role.userCount} user${role.userCount == 1 ? '' : 's'}';

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          ClayContainer(
            variant: ClayVariant.soft,
            color: editable ? lum.accentSoft : lum.g100,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            width: 44,
            height: 44,
            child: Icon(LucideIcons.shield,
                size: 20, color: editable ? lum.accent : lum.g500),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        role.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.headline
                            .copyWith(fontSize: 15, color: lum.textPrimary),
                      ),
                    ),
                    if (role.isSystemRole) ...[
                      const SizedBox(width: 8),
                      const AppPill(
                          label: 'System',
                          tone: AppPillTone.neutral,
                          showDot: false),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.footnote.copyWith(color: lum.g500),
                ),
                const SizedBox(height: 6),
                Text(
                  counts,
                  style: AppTypography.caption.copyWith(color: lum.g500),
                ),
              ],
            ),
          ),
          if (editable) ...[
            const SizedBox(width: 8),
            Icon(LucideIcons.chevronRight, size: 20, color: lum.g400),
          ],
        ],
      ),
    );
  }
}
