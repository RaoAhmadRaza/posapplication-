import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase.dart';

class NotificationRemoteDataSource {
  final SupabaseClient _client = supabase;
  String? _cachedTenantId;

  Future<String> _tenantId() async {
    if (_cachedTenantId != null) return _cachedTenantId!;
    final data = await _client.from('users').select('tenant_id').single();
    _cachedTenantId = data['tenant_id'] as String;
    return _cachedTenantId!;
  }

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

  // --- Templates admin (direct RLS writes, gated notifications:update) --------
  Future<List<Map<String, dynamic>>> loadSmsTemplates() async {
    return _client
        .from('sms_templates')
        .select('id, template_code, name, body, language, is_active')
        .order('template_code');
  }

  Future<List<Map<String, dynamic>>> loadEmailTemplates() async {
    return _client
        .from('email_templates')
        .select('id, template_code, name, subject, body_html, language, is_active')
        .order('template_code');
  }

  Future<void> upsertSmsTemplate(Map<String, dynamic> data) async {
    final id = data['id'];
    if (id != null) {
      await _client.from('sms_templates').update(data..remove('id')).eq('id', id);
    } else {
      await _client
          .from('sms_templates')
          .insert({...data..remove('id'), 'tenant_id': await _tenantId()});
    }
  }

  Future<void> upsertEmailTemplate(Map<String, dynamic> data) async {
    final id = data['id'];
    if (id != null) {
      await _client
          .from('email_templates')
          .update(data..remove('id'))
          .eq('id', id);
    } else {
      await _client
          .from('email_templates')
          .insert({...data..remove('id'), 'tenant_id': await _tenantId()});
    }
  }

  // --- Communication logs (read) ---------------------------------------------
  Future<List<Map<String, dynamic>>> loadCommunicationLogs() async {
    return _client
        .from('communication_logs')
        .select('id, channel, template_code, recipient, status, sent_at, error, created_at')
        .order('created_at', ascending: false)
        .limit(200);
  }

  Future<List<Map<String, dynamic>>> loadReportDeliveries() async {
    return _client
        .from('report_deliveries')
        .select('id, channel, recipient, status, sent_at, error, created_at')
        .order('created_at', ascending: false)
        .limit(200);
  }

  Future<List<Map<String, dynamic>>> loadOutboundNotifications() async {
    return _client
        .from('notifications')
        .select('id, channel, status, sent_at, failed_reason, created_at')
        .neq('channel', 'IN_APP')
        .order('created_at', ascending: false)
        .limit(200);
  }

  // --- Bulk send (definer RPC — communication_logs has no INSERT policy) ------
  Future<int> previewBulk(String segment, String? tag, String channel) async {
    final res = await _client.rpc('enqueue_bulk_communication', params: {
      'p_segment': segment,
      'p_tag': tag,
      'p_template_code': '',
      'p_channel': channel,
      'p_dry_run': true,
    });
    return (res as Map)['enqueued'] as int? ?? 0;
  }

  Future<int> enqueueBulk(
    String segment,
    String? tag,
    String templateCode,
    String channel,
  ) async {
    final res = await _client.rpc('enqueue_bulk_communication', params: {
      'p_segment': segment,
      'p_tag': tag,
      'p_template_code': templateCode,
      'p_channel': channel,
      'p_dry_run': false,
    });
    return (res as Map)['enqueued'] as int? ?? 0;
  }
}
