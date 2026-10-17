class AlertRecipientModel {
  final int? id;
  final int? localAlertId;
  final int? contactId;
  final String? contactName;
  final String phone;
  final String status; // 'sent' | 'failed'
  final String? error;

  AlertRecipientModel({
    this.id,
    this.localAlertId,
    this.contactId,
    this.contactName,
    required this.phone,
    required this.status,
    this.error,
  });

  Map<String, dynamic> toMap(int alertId) {
    return {
      'local_alert_id': alertId,
      'contact_id': contactId,
      'phone': phone,
      'status': status,
      'error': error,
    };
  }

  factory AlertRecipientModel.fromMap(Map<String, dynamic> map) {
    return AlertRecipientModel(
      id: map['id'] as int?,
      localAlertId: map['local_alert_id'] as int?,
      contactId: map['contact_id'] as int?,
      phone: map['phone'] as String? ?? '',
      status: map['status'] as String? ?? 'sent',
      error: map['error'] as String?,
    );
  }

  Map<String, dynamic> toRemoteJson() {
    return {
      if (contactId != null) 'contact_id': contactId,
      'phone': phone,
      'status': status,
      'error': error,
    };
  }

  factory AlertRecipientModel.fromRemoteJson(Map<String, dynamic> json) {
    return AlertRecipientModel(
      id: json['id'] as int?,
      contactId: json['contact_id'] as int?,
      contactName: json['contact_name'] as String?,
      phone: json['phone'] as String? ?? '',
      status: json['status'] as String? ?? 'sent',
      error: json['error'] as String?,
    );
  }
}

class AlertModel {
  final int? id;
  final int? remoteId;
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final String locationSource; // 'live' | 'last_known'
  final String message;
  final DateTime triggeredAt;
  final int sentCount;
  final int failedCount;
  final bool isSynced;
  final List<AlertRecipientModel> recipients;

  AlertModel({
    this.id,
    this.remoteId,
    this.latitude,
    this.longitude,
    this.accuracy,
    this.locationSource = 'live',
    required this.message,
    required this.triggeredAt,
    this.sentCount = 0,
    this.failedCount = 0,
    this.isSynced = false,
    this.recipients = const [],
  });

  String get mapUrl {
    if (latitude != null && longitude != null) {
      return 'https://maps.google.com/?q=$latitude,$longitude';
    }
    return '';
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'remote_id': remoteId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'location_source': locationSource,
      'message': message,
      'triggered_at': triggeredAt.toIso8601String(),
      'sent_count': sentCount,
      'failed_count': failedCount,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory AlertModel.fromMap(Map<String, dynamic> map, {List<AlertRecipientModel> recipients = const []}) {
    return AlertModel(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as int?,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      accuracy: map['accuracy'] != null ? (map['accuracy'] as num).toDouble() : null,
      locationSource: map['location_source'] as String? ?? 'live',
      message: map['message'] as String? ?? '',
      triggeredAt: map['triggered_at'] != null ? DateTime.parse(map['triggered_at'] as String) : DateTime.now(),
      sentCount: map['sent_count'] as int? ?? 0,
      failedCount: map['failed_count'] as int? ?? 0,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      recipients: recipients,
    );
  }

  Map<String, dynamic> toRemoteJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'location_source': locationSource,
      'message': message,
      'triggered_at': triggeredAt.toIso8601String(),
      'sent_count': sentCount,
      'failed_count': failedCount,
      'recipients': recipients.map((r) => r.toRemoteJson()).toList(),
    };
  }

  factory AlertModel.fromRemoteJson(Map<String, dynamic> json) {
    final rawRecipients = json['recipients'] as List<dynamic>? ?? [];
    return AlertModel(
      id: null,
      remoteId: json['id'] as int?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      accuracy: json['accuracy'] != null ? (json['accuracy'] as num).toDouble() : null,
      locationSource: json['location_source'] as String? ?? 'live',
      message: json['message'] as String? ?? '',
      triggeredAt: json['triggered_at'] != null ? DateTime.parse(json['triggered_at'] as String) : DateTime.now(),
      sentCount: json['sent_count'] as int? ?? 0,
      failedCount: json['failed_count'] as int? ?? 0,
      isSynced: true,
      recipients: rawRecipients.map((r) => AlertRecipientModel.fromRemoteJson(r as Map<String, dynamic>)).toList(),
    );
  }
}

