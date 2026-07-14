import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/notification.dart';
import '../../domain/entities/message_template.dart';
import '../../domain/entities/communication_log.dart';
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

  // --- Templates -------------------------------------------------------------
  Future<List<MessageTemplate>> loadTemplates() async {
    final sms = await _ds.loadSmsTemplates();
    final email = await _ds.loadEmailTemplates();
    return [
      for (final r in sms)
        MessageTemplate(
          id: r['id'] as String?,
          channel: TemplateChannel.sms,
          templateCode: r['template_code'] as String,
          name: r['name'] as String,
          body: (r['body'] as String?) ?? '',
          language: (r['language'] as String?) ?? 'en',
          isActive: r['is_active'] as bool? ?? true,
        ),
      for (final r in email)
        MessageTemplate(
          id: r['id'] as String?,
          channel: TemplateChannel.email,
          templateCode: r['template_code'] as String,
          name: r['name'] as String,
          subject: r['subject'] as String?,
          body: (r['body_html'] as String?) ?? '',
          language: (r['language'] as String?) ?? 'en',
          isActive: r['is_active'] as bool? ?? true,
        ),
    ];
  }

  Future<void> upsertTemplate(MessageTemplate t) async {
    if (t.channel == TemplateChannel.sms) {
      await _ds.upsertSmsTemplate({
        'id': t.id,
        'template_code': t.templateCode,
        'name': t.name,
        'body': t.body,
        'language': t.language,
        'is_active': t.isActive,
      });
    } else {
      await _ds.upsertEmailTemplate({
        'id': t.id,
        'template_code': t.templateCode,
        'name': t.name,
        'subject': t.subject ?? '',
        'body_html': t.body,
        'language': t.language,
        'is_active': t.isActive,
      });
    }
  }

  // --- Communication logs (merged, newest first) -----------------------------
  Future<List<CommunicationLogEntry>> loadCommunicationLog() async {
    final comms = await _ds.loadCommunicationLogs();
    final reports = await _ds.loadReportDeliveries();
    final notifs = await _ds.loadOutboundNotifications();

    DateTime? ts(dynamic v) => v == null ? null : DateTime.parse(v as String);

    final entries = <CommunicationLogEntry>[
      for (final r in comms)
        CommunicationLogEntry(
          id: r['id'] as String,
          source: CommSource.communication,
          channel: r['channel'] as String? ?? 'EMAIL',
          templateCode: r['template_code'] as String?,
          recipient: r['recipient'] as String?,
          status: r['status'] as String? ?? 'PENDING',
          sentAt: ts(r['sent_at']),
          error: r['error'] as String?,
          createdAt: DateTime.parse(r['created_at'] as String),
        ),
      for (final r in reports)
        CommunicationLogEntry(
          id: r['id'] as String,
          source: CommSource.reportDelivery,
          channel: r['channel'] as String? ?? 'EMAIL',
          recipient: r['recipient'] as String?,
          status: r['status'] as String? ?? 'PENDING',
          sentAt: ts(r['sent_at']),
          error: r['error'] as String?,
          createdAt: DateTime.parse(r['created_at'] as String),
        ),
      for (final r in notifs)
        CommunicationLogEntry(
          id: r['id'] as String,
          source: CommSource.notification,
          channel: r['channel'] as String? ?? 'PUSH',
          status: r['status'] as String? ?? 'PENDING',
          sentAt: ts(r['sent_at']),
          error: r['failed_reason'] as String?,
          createdAt: DateTime.parse(r['created_at'] as String),
        ),
    ];
    entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return entries;
  }

  Future<int> previewBulk(String segment, String? tag, String channel) =>
      _ds.previewBulk(segment, tag, channel);

  Future<int> enqueueBulk(
    String segment,
    String? tag,
    String templateCode,
    String channel,
  ) =>
      _ds.enqueueBulk(segment, tag, templateCode, channel);
}
