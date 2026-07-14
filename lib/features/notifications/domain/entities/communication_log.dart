enum CommSource { communication, reportDelivery, notification }

/// A unified outbound row for the logs screen — merges communication_logs,
/// report_deliveries, and non-IN_APP notifications.
class CommunicationLogEntry {
  final String id;
  final CommSource source;
  final String channel;
  final String? templateCode;
  final String? recipient;
  final String status; // PENDING / SENT / FAILED / ...
  final DateTime? sentAt;
  final String? error;
  final DateTime createdAt;

  const CommunicationLogEntry({
    required this.id,
    required this.source,
    required this.channel,
    this.templateCode,
    this.recipient,
    required this.status,
    this.sentAt,
    this.error,
    required this.createdAt,
  });
}
