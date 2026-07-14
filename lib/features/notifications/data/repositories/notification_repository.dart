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

  Future<List<NotificationPreference>> loadPreferences() async {
    final rows = await _ds.loadPreferences();
    return rows.map((r) {
      final raw = (r['channels'] as List?) ?? const [];
      return NotificationPreference(
        eventType: r['event_type'] as String,
        channels: raw.map((c) => _channelFromCode(c as String)).toSet(),
        enabled: r['enabled'] as bool? ?? true,
      );
    }).toList();
  }

  Future<void> upsertPreference(NotificationPreference pref) async {
    await _ds.upsertPreference(
      pref.eventType,
      pref.channels.map((c) => c.code).toList(),
      pref.enabled,
    );
  }

  NotificationChannel _channelFromCode(String v) => switch (v) {
        'PUSH' => NotificationChannel.push,
        'SMS' => NotificationChannel.sms,
        'EMAIL' => NotificationChannel.email,
        'WHATSAPP' => NotificationChannel.whatsapp,
        _ => NotificationChannel.inApp,
      };
}
