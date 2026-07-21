import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_typography.dart';
import '../controllers/notifications_controller.dart';

/// Global notification bell + unread badge. Drop into any AppBar `actions`.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lum = context.lum;
    final unread = ref.watch(unreadCountStreamProvider).value ?? 0;

    return Tooltip(
      message: 'Notifications',
      child: Semantics(
        button: true,
        label: unread > 0
            ? 'Notifications, $unread unread'
            : 'Notifications',
        child: InkWell(
          onTap: () => context.push('/notifications'),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(LucideIcons.bell, size: 20, color: lum.g600),
                if (unread > 0)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: lum.danger,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        // Ring in the header fill so the badge reads as lifted.
                        border: Border.all(color: lum.surface, width: 1.5),
                      ),
                      child: Text(
                        unread > 99 ? '99+' : '$unread',
                        textAlign: TextAlign.center,
                        style: AppTypography.caption.copyWith(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
