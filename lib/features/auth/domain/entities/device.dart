class Device {
  final String id;
  final String deviceName;
  final String deviceModel;
  final String osInfo;
  final String trustLevel;
  final bool authorized;
  final String? lastSeenAt;
  final String? authorizedAt;
  final String? authorizedBy;

  const Device({
    required this.id,
    required this.deviceName,
    required this.deviceModel,
    required this.osInfo,
    required this.trustLevel,
    required this.authorized,
    this.lastSeenAt,
    this.authorizedAt,
    this.authorizedBy,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'] as String,
      deviceName: json['device_name'] as String? ?? '',
      deviceModel: json['device_model'] as String? ?? '',
      osInfo: json['os_info'] as String? ?? '',
      trustLevel: json['trust_level'] as String? ?? 'PENDING',
      authorized: json['authorized'] as bool? ?? false,
      lastSeenAt: json['last_seen_at'] as String?,
      authorizedAt: json['authorized_at'] as String?,
      authorizedBy: json['authorized_by'] as String?,
    );
  }
}
