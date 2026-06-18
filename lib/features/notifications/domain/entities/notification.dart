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
