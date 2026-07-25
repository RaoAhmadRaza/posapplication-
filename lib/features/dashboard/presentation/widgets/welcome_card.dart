import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/clay.dart';
import '../../../../core/design/widgets/app_hover.dart';
import '../../../auth/presentation/controllers/profile_controller.dart';

/// Greeting card: avatar initial, the signed-in name, and role · tenant.
class WelcomeCard extends ConsumerWidget {
  const WelcomeCard({super.key, this.fallbackName});

  /// Shown when the profile has not resolved yet (typically the auth email).
  final String? fallbackName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final profile = ref.watch(profileControllerProvider).value;
    final name = profile?.fullName ?? fallbackName ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return AppHover(
      child: ClayContainer(
        variant: ClayVariant.raised,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [lum.surface, lum.g100],
        ),
        borderRadius: AppRadius.lg,
        isDark: lum.isDark,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClayContainer(
              variant: ClayVariant.lumen,
              // The lumen variant paints no fill of its own — without an
              // explicit colour the avatar renders as shadow only.
              color: lum.accent,
              borderRadius: 23,
              isDark: lum.isDark,
              width: 46,
              height: 46,
              child: Center(
                child: Text(
                  initial,
                  style: AppTypography.title3.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome, $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.headline.copyWith(
                      fontFamily: AppTypography.display,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.18,
                      color: lum.textPrimary,
                    ),
                  ),
                  if (profile?.roleName != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${profile!.roleName} · ${profile.tenantName ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
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
  }
}
