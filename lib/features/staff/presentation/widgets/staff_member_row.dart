import 'package:flutter/material.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../domain/entities/staff_entities.dart';
import 'staff_ui.dart';

/// One member in the roles/members tab: initials avatar, name + email, the
/// current role pill, and an optional (gated) "Change" control from the page.
class StaffMemberRow extends StatelessWidget {
  const StaffMemberRow({super.key, required this.user, this.trailing});

  final TenantUser user;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final name =
        user.fullName?.trim().isNotEmpty == true ? user.fullName!.trim() : (user.email ?? 'User');

    return ClayContainer(
      variant: ClayVariant.soft,
      color: lum.surface,
      borderRadius: AppRadius.lg,
      isDark: lum.isDark,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          ClayContainer(
            variant: ClayVariant.soft,
            color: lum.accentSoft,
            borderRadius: AppRadius.md,
            isDark: lum.isDark,
            width: 44,
            height: 44,
            child: Center(
              child: Text(
                staffInitials(user.fullName, user.email),
                style: AppTypography.title2
                    .copyWith(fontSize: 15, color: lum.accentPress),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headline
                      .copyWith(fontSize: 15, color: lum.textPrimary),
                ),
                if (user.email != null && user.fullName?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    user.email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.footnote.copyWith(color: lum.g500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          AppPill(
            label: user.roleName ?? 'No role',
            tone: AppPillTone.neutral,
            showDot: false,
          ),
          ?trailing,
        ],
      ),
    );
  }
}
