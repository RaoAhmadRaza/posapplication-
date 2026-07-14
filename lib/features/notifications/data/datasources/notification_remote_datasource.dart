import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase.dart';

class NotificationRemoteDataSource {
  final SupabaseClient _client = supabase;

  static const _cols =
      'id, tenant_id, user_id, title, body, channel, priority, status,'
      ' action_url, action_type, action_id, read_at, sent_at, delivered_at,'
      ' failed_reason, metadata, created_at';

  Future<List<Map<String, dynamic>>> loadNotifications() async {
    return _client
        .from('notifications')
        .select(_cols)
        .order('created_at', ascending: false)
        .limit(100);
  }

  Future<int> unreadCount() async {
    final n = await _client.rpc('unread_notification_count');
    return (n as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) async {
    await _client.rpc('mark_notification_read', params: {'p_id': id});
  }

  Future<void> markAllRead() async {
    await _client.rpc('mark_all_notifications_read');
  }

  Future<List<Map<String, dynamic>>> loadPreferences() async {
    return _client
        .from('notification_preferences')
        .select('event_type, channels, enabled');
  }

  Future<void> upsertPreference(
    String eventType,
    List<String> channels,
    bool enabled,
  ) async {
    await _client.rpc('upsert_notification_preference', params: {
      'p_event_type': eventType,
      'p_channels': channels,
      'p_enabled': enabled,
    });
  }
}
