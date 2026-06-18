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
    final list = await _client
        .from('notifications')
        .select('id')
        .filter('read_at', 'is', null)
        .limit(100);
    return list.length;
  }

  Future<void> markRead(String id) async {
    await _client.rpc('mark_notification_read', params: {'p_id': id});
  }

  Future<void> markAllRead() async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String(), 'status': 'READ'})
        .filter('read_at', 'is', null);
  }
}
