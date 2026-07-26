import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_typography.dart';
import '../../../../core/design/widgets/app_button.dart';
import '../../../../core/design/widgets/app_card.dart';
import '../../../../core/design/widgets/app_detail_scaffold.dart';
import '../../../../core/design/widgets/app_filter_chips.dart';
import '../../../../core/design/widgets/app_pill.dart';
import '../../../../core/design/widgets/app_states.dart';
import '../../domain/entities/notification.dart';
import '../controllers/notifications_controller.dart';

/// Inbox filter chips (single-select). Index 0 = unread, 1 = all, 2..5 map to
/// the four priorities. Matches the design's merged filter row.
const _filterLabels = ['Unread', 'All', 'Low', 'Normal', 'High', 'Urgent'];

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  int _filter = 0; // default: unread

  bool _matches(AppNotification n) => switch (_filter) {
        0 => n.isUnread,
        1 => true,
        2 => n.priority == NotificationPriority.low,
        3 => n.priority == NotificationPriority.normal,
        4 => n.priority == NotificationPriority.high,
        _ => n.priority == NotificationPriority.urgent,
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);
    final unread = ref.watch(unreadCountProvider).value ?? 0;

    return AppDetailScaffold(
      eyebrow: 'Notifications',
      title: 'Notifications',
      description: 'Alerts across sales, stock, repairs and more.',
      actions: [
        if (unread > 0)
          AppButton(
            label: 'Mark all read',
            variant: AppButtonVariant.plain,
            icon: LucideIcons.checkCheck,
            onPressed: () =>
                ref.read(notificationsControllerProvider.notifier).markAllRead(),
          ),
        _GearButton(onTap: () => context.push('/notifications/settings')),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppFilterChips(
            labels: _filterLabels,
            selected: _filter,
            onSelected: (i) => setState(() => _filter = i),
          ),
          const SizedBox(height: AppSpacing.lg),
          state.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: 64),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => AppErrorState(
              title: 'Unable to load notifications',
              body: 'Check your connection and try again.',
              onRetry: () =>
                  ref.read(notificationsControllerProvider.notifier).refresh(),
            ),
            data: (all) {
              final items = all.where(_matches).toList();
              if (items.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 48),
                  child: AppEmptyState(
                    icon: LucideIcons.bell,
                    title: 'No notifications',
                    body: "You're all caught up — new alerts will show up here.",
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(height: AppSpacing.md),
                    _NotificationCard(
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
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Ghost icon button used for the inbox → settings shortcut. 44dp target.
class _GearButton extends StatelessWidget {
  const _GearButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    return Semantics(
      button: true,
      label: 'Notification settings',
      child: IconButton(
        onPressed: onTap,
        tooltip: 'Settings',
        icon: Icon(LucideIcons.settings, size: 20, color: lum.g600),
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

/// Glyph for a notification, keyed off action_type. Unknown types fall back to
/// the bell rather than guessing.
IconData _typeIcon(String? type) {
  switch (type?.toLowerCase()) {
    case 'repair':
      return LucideIcons.wrench;
    case 'customer':
      return LucideIcons.userRound;
    case 'product':
    case 'low_stock':
      return LucideIcons.package;
    case 'payroll_run':
      return LucideIcons.wallet;
    default:
      return LucideIcons.bell;
  }
}

AppPillTone _priorityTone(NotificationPriority p) => switch (p) {
      NotificationPriority.low => AppPillTone.neutral,
      NotificationPriority.normal => AppPillTone.lumen,
      NotificationPriority.high => AppPillTone.warning,
      NotificationPriority.urgent => AppPillTone.danger,
    };

String _priorityLabel(NotificationPriority p) => switch (p) {
      NotificationPriority.low => 'Low',
      NotificationPriority.normal => 'Normal',
      NotificationPriority.high => 'High',
      NotificationPriority.urgent => 'Urgent',
    };

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lum = context.lum;
    final n = notification;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: lum.accentSoft,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(_typeIcon(n.actionType), size: 20, color: lum.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          if (n.isUnread) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: lum.accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              n.title,
                              style: AppTypography.callout.copyWith(
                                fontWeight: FontWeight.w600,
                                color: lum.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    AppPill(
                      label: _priorityLabel(n.priority),
                      tone: _priorityTone(n.priority),
                      showDot: false,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  n.body,
                  style: AppTypography.footnote.copyWith(color: lum.g600),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (n.actionId != null) ...[
                      Flexible(
                        child: Text(
                          n.actionId!,
                          style: AppTypography.monoValue.copyWith(
                            fontSize: 12,
                            color: lum.g500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('  ·  ',
                          style: AppTypography.caption.copyWith(color: lum.g400)),
                    ],
                    Text(
                      _formatTime(n.createdAt),
                      style: AppTypography.caption.copyWith(color: lum.g500),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
