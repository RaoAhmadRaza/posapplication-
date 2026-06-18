import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_inline_banner.dart';
import '../../domain/entities/notification.dart';
import '../controllers/notifications_controller.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.accent, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Notifications', style: AppTypography.headline),
        actions: [
          if (unread > 0)
            AppButton(
              label: 'Mark All Read',
              variant: AppButtonVariant.plain,
              onPressed: () =>
                  ref.read(notificationsControllerProvider.notifier).markAllRead(),
            ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppInlineBanner(
                  message: 'Could not load notifications.',
                  type: BannerType.error,
                ),
                const SizedBox(height: AppSpacing.md),
                AppButton(
                  label: 'Retry',
                  onPressed: () => ref
                      .read(notificationsControllerProvider.notifier)
                      .refresh(),
                ),
              ],
            ),
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 48, color: AppColors.textHint),
                  const SizedBox(height: AppSpacing.md),
                  Text('No notifications', style: AppTypography.subhead.copyWith(color: AppColors.textMuted)),
                  Text('Low-stock alerts and more will appear here.', style: AppTypography.footnote.copyWith(color: AppColors.textHint)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
              vertical: AppSpacing.md,
            ),
            itemCount: notifications.length,
            itemBuilder: (_, i) => Padding(
              padding: EdgeInsets.only(
                bottom: i < notifications.length - 1 ? AppSpacing.md : 0,
              ),
              child: _NotificationCard(
                notification: notifications[i],
                onTap: () {
                  final n = notifications[i];
                  if (n.isUnread) {
                    ref
                        .read(notificationsControllerProvider.notifier)
                        .markRead(n.id);
                  }
                  if (n.actionType == 'low_stock' && n.actionId != null) {
                    context.push('/inventory/stock/${n.actionId}');
                  }
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notification.isUnread)
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: AppSpacing.sm),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                const SizedBox(width: AppSpacing.md + 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: notification.isUnread
                                ? AppTypography.callout
                                    .copyWith(fontWeight: FontWeight.w600)
                                : AppTypography.callout,
                          ),
                        ),
                        _PriorityChip(priority: notification.priority),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: AppTypography.footnote.copyWith(color: AppColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(notification.createdAt),
                      style: AppTypography.caption.copyWith(color: AppColors.textHint),
                    ),
                  ],
                ),
              ),
              if (notification.actionType == 'low_stock')
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.sm),
                  child: Icon(Icons.chevron_right, size: 18, color: AppColors.separator),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _PriorityChip extends StatelessWidget {
  const _PriorityChip({required this.priority});

  final NotificationPriority priority;

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (priority) {
      case NotificationPriority.low:
        color = AppColors.textMuted;
        label = 'LOW';
        break;
      case NotificationPriority.high:
        color = AppColors.warning;
        label = 'HIGH';
        break;
      case NotificationPriority.urgent:
        color = AppColors.destructive;
        label = 'URGENT';
        break;
      default:
        color = AppColors.accent;
        label = 'NORMAL';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.chip),
      ),
      child: Text(
        label,
        style: AppTypography.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
