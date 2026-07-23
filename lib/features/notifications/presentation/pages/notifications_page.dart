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

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  NotificationPriority? _priority;
  bool _unreadOnly = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final priorityFilter = _priority;
    final unreadOnly = _unreadOnly;

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
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.accent, size: 22),
            tooltip: 'Settings',
            onPressed: () => context.push('/notifications/settings'),
          ),
          if (unread > 0)
            AppButton(
              label: 'Mark All Read',
              variant: AppButtonVariant.plain,
              onPressed: () =>
                  ref.read(notificationsControllerProvider.notifier).markAllRead(),
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            priority: priorityFilter,
            unreadOnly: unreadOnly,
            onUnreadToggle: () => setState(() => _unreadOnly = !_unreadOnly),
            onPriority: (p) => setState(() => _priority = p),
          ),
          Expanded(
            child: state.when(
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
              data: (all) {
                final items = all.where((n) {
                  if (priorityFilter != null && n.priority != priorityFilter) {
                    return false;
                  }
                  if (unreadOnly && !n.isUnread) return false;
                  return true;
                }).toList();

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.read(notificationsControllerProvider.notifier).refresh(),
                  child: items.isEmpty
                      ? ListView(
                          children: [
                            const SizedBox(height: 120),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.notifications_none,
                                    size: 48, color: AppColors.textHint),
                                const SizedBox(height: AppSpacing.md),
                                Text('No notifications',
                                    style: AppTypography.subhead
                                        .copyWith(color: AppColors.textMuted)),
                              ],
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.screenPadding,
                            vertical: AppSpacing.md,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) => Padding(
                            padding: EdgeInsets.only(
                              bottom: i < items.length - 1 ? AppSpacing.md : 0,
                            ),
                            child: _NotificationCard(
                              notification: items[i],
                              onTap: () {
                                final n = items[i];
                                if (n.isUnread) {
                                  ref
                                      .read(notificationsControllerProvider.notifier)
                                      .markRead(n.id);
                                }
                                _deepLink(context, n);
                              },
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Route a notification to its target screen via action_type/action_id,
/// falling back to a validated action_url.
void _deepLink(BuildContext context, AppNotification n) {
  final id = n.actionId;
  switch (n.actionType) {
    case 'repair':
    case 'REPAIR':
      // Repair lives in the nav shell; go keeps the rail/bottom bar.
      if (id != null) context.go('/repair/$id');
      return;
    case 'customer':
      // Customers lives in the nav shell; go keeps the rail/bottom bar.
      if (id != null) context.go('/customers/$id');
      return;
    case 'product':
    case 'low_stock':
      if (id != null) context.push('/inventory/stock/$id');
      return;
    case 'payroll_run':
      if (id != null) context.push('/hr/payroll/$id');
      return;
  }
  final url = n.actionUrl;
  if (url != null && url.startsWith('/')) context.push(url);
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.priority,
    required this.unreadOnly,
    required this.onUnreadToggle,
    required this.onPriority,
  });

  final NotificationPriority? priority;
  final bool unreadOnly;
  final VoidCallback onUnreadToggle;
  final ValueChanged<NotificationPriority?> onPriority;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.separator, width: 0.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _Chip(label: 'Unread', selected: unreadOnly, onTap: onUnreadToggle),
            const SizedBox(width: AppSpacing.sm),
            Container(width: 0.5, height: 20, color: AppColors.separator),
            const SizedBox(width: AppSpacing.sm),
            _Chip(
              label: 'All',
              selected: priority == null,
              onTap: () => onPriority(null),
            ),
            for (final p in NotificationPriority.values) ...[
              const SizedBox(width: AppSpacing.sm),
              _Chip(
                label: _priorityLabel(p),
                selected: priority == p,
                onTap: () => onPriority(p),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _priorityLabel(NotificationPriority p) => switch (p) {
      NotificationPriority.low => 'Low',
      NotificationPriority.normal => 'Normal',
      NotificationPriority.high => 'High',
      NotificationPriority.urgent => 'Urgent',
    };

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.12)
              : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.separator,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.footnote.copyWith(
            color: selected ? AppColors.accent : AppColors.textMuted,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
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
              if (notification.actionType != null)
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
