enum NotificationChannel { inApp, push, sms, email, whatsapp }

enum NotificationPriority { low, normal, high, urgent }

enum NotificationStatus { pending, sent, delivered, read, failed }

class AppNotification {
  final String id;
  final String tenantId;
  final String userId;
  final String title;
  final String body;
  final NotificationChannel channel;
  final NotificationPriority priority;
  final NotificationStatus status;
  final String? actionUrl;
  final String? actionType;
  final String? actionId;
  final DateTime? readAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final String? failedReason;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.title,
    required this.body,
    required this.channel,
    required this.priority,
    required this.status,
    this.actionUrl,
    this.actionType,
    this.actionId,
    this.readAt,
    this.sentAt,
    this.deliveredAt,
    this.failedReason,
    this.metadata,
    required this.createdAt,
  });

  bool get isUnread => readAt == null;
}

extension NotificationChannelCode on NotificationChannel {
  String get code => switch (this) {
        NotificationChannel.inApp => 'IN_APP',
        NotificationChannel.push => 'PUSH',
        NotificationChannel.sms => 'SMS',
        NotificationChannel.email => 'EMAIL',
        NotificationChannel.whatsapp => 'WHATSAPP',
      };

  String get label => switch (this) {
        NotificationChannel.inApp => 'In-app',
        NotificationChannel.push => 'Push',
        NotificationChannel.sms => 'SMS',
        NotificationChannel.email => 'Email',
        NotificationChannel.whatsapp => 'WhatsApp',
      };
}

class NotificationPreference {
  final String eventType;
  final Set<NotificationChannel> channels;
  final bool enabled;

  const NotificationPreference({
    required this.eventType,
    required this.channels,
    required this.enabled,
  });

  NotificationPreference copyWith({
    Set<NotificationChannel>? channels,
    bool? enabled,
  }) =>
      NotificationPreference(
        eventType: eventType,
        channels: channels ?? this.channels,
        enabled: enabled ?? this.enabled,
      );
}
