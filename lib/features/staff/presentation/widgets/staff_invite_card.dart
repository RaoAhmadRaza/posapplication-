import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/staff_entities.dart';
import 'staff_ui.dart';

/// One row of the staff-invites list: initials avatar, name + email, a
/// role · branches · sent meta line, the status pill, and an optional (gated)
/// overflow menu supplied by the page.
class StaffInviteCard extends StatelessWidget {
  const StaffInviteCard({super.key, required this.invite, this.menu});

  final StaffInvite invite;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final (statusLabel, tone) = inviteStatusUi(invite.effectiveStatus);
    final hasName = invite.fullName?.trim().isNotEmpty == true;
    final title = hasName ? invite.fullName!.trim() : (invite.email ?? 'Open link');
    final branchCount = invite.branchNames.length;
    final meta =
        '${invite.roleName} · $branchCount branch${branchCount == 1 ? '' : 'es'} · ${relativeSince(invite.createdAt)}';

    return ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // ClayVariant.soft with an explicit fill — the lumen variant paints no
          // fill of its own. Named invites get an accent tile, open links a grey.
          ClayContainer(
            variant: ClayVariant.soft,
            color: hasName ? lum.accentSoft : lum.surface2,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            width: 44,
            height: 44,
            child: Center(
              child: hasName
                  ? Text(
                      staffInitials(invite.fullName, invite.email),
                      style: AppTypography.title2.copyWith(
                        fontSize: 15,
                        color: lum.accentPress,
                      ),
                    )
                  : Icon(LucideIcons.link, size: 18, color: lum.g500),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headline
                      .copyWith(fontSize: 15, color: lum.textPrimary),
                ),
                if (hasName && invite.email != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    invite.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.footnote.copyWith(color: lum.g500),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(color: lum.g500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppPill(label: statusLabel, tone: tone),
          ?menu,
        ],
      ),
    );
  }
}
