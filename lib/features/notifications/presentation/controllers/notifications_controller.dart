import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/notification.dart';
import '../../data/repositories/notification_repository.dart';

final notificationsControllerProvider =
    AsyncNotifierProvider<NotificationsController, List<AppNotification>>(
  NotificationsController.new,
);

final unreadCountProvider = FutureProvider<int>((ref) async {
  return ref.read(notificationRepositoryProvider).unreadCount();
});

class NotificationsController
    extends AsyncNotifier<List<AppNotification>> {
  @override
  Future<List<AppNotification>> build() async {
    return ref.read(notificationRepositoryProvider).loadNotifications();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(notificationRepositoryProvider).loadNotifications();
    });
  }

  Future<void> markRead(String id) async {
    await ref.read(notificationRepositoryProvider).markRead(id);
    ref.invalidate(unreadCountProvider);
    final current = state.value ?? <AppNotification>[];
    state = AsyncValue.data(current.map((n) {
      if (n.id == id && n.isUnread) {
        return AppNotification(
          id: n.id, tenantId: n.tenantId, userId: n.userId,
          title: n.title, body: n.body, channel: n.channel,
          priority: n.priority,
          status: NotificationStatus.read,
          actionUrl: n.actionUrl, actionType: n.actionType, actionId: n.actionId,
          readAt: DateTime.now(),
          sentAt: n.sentAt, deliveredAt: n.deliveredAt,
          failedReason: n.failedReason, metadata: n.metadata,
          createdAt: n.createdAt,
        );
      }
      return n;
    }).toList());
  }

  Future<void> markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    ref.invalidate(unreadCountProvider);
    ref.invalidateSelf();
  }
}
