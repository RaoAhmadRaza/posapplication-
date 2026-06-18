import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/notification.dart';
import '../datasources/notification_remote_datasource.dart';
import '../models/notification_model.dart';

final notificationRepositoryProvider =
    Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(notificationDataSourceProvider));
});

final notificationDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
  return NotificationRemoteDataSource();
});

class NotificationRepository {
  final NotificationRemoteDataSource _ds;

  NotificationRepository(this._ds);

  Future<List<AppNotification>> loadNotifications() async {
    final rows = await _ds.loadNotifications();
    return rows.map(NotificationModel.fromJson).toList();
  }

  Future<int> unreadCount() async {
    return _ds.unreadCount();
  }

  Future<void> markRead(String id) async {
    await _ds.markRead(id);
  }

  Future<void> markAllRead() async {
    await _ds.markAllRead();
  }
}
