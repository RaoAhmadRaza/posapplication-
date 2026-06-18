import '../../domain/entities/notification.dart';

class NotificationModel {
  static AppNotification fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      channel: _parseChannel(json['channel'] as String),
      priority: _parsePriority(json['priority'] as String),
      status: _parseStatus(json['status'] as String),
      actionUrl: json['action_url'] as String?,
      actionType: json['action_type'] as String?,
      actionId: json['action_id'] as String?,
      readAt: _parseDateTime(json['read_at']),
      sentAt: _parseDateTime(json['sent_at']),
      deliveredAt: _parseDateTime(json['delivered_at']),
      failedReason: json['failed_reason'] as String?,
      metadata: _parseMetadata(json['metadata']),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static NotificationChannel _parseChannel(String v) {
    switch (v) {
      case 'PUSH': return NotificationChannel.push;
      case 'SMS': return NotificationChannel.sms;
      case 'EMAIL': return NotificationChannel.email;
      case 'WHATSAPP': return NotificationChannel.whatsapp;
      default: return NotificationChannel.inApp;
    }
  }

  static NotificationPriority _parsePriority(String v) {
    switch (v) {
      case 'LOW': return NotificationPriority.low;
      case 'HIGH': return NotificationPriority.high;
      case 'URGENT': return NotificationPriority.urgent;
      default: return NotificationPriority.normal;
    }
  }

  static NotificationStatus _parseStatus(String v) {
    switch (v) {
      case 'SENT': return NotificationStatus.sent;
      case 'DELIVERED': return NotificationStatus.delivered;
      case 'READ': return NotificationStatus.read;
      case 'FAILED': return NotificationStatus.failed;
      default: return NotificationStatus.pending;
    }
  }

  static DateTime? _parseDateTime(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.parse(v);
    return null;
  }

  static Map<String, dynamic>? _parseMetadata(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }
}
