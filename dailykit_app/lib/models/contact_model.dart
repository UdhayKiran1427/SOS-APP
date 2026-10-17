class ContactModel {
  final int? id;
  final int? remoteId;
  final String name;
  final String phoneE164;
  final bool isActive;
  final int priority;
  final bool isSynced;
  final DateTime? updatedAt;

  ContactModel({
    this.id,
    this.remoteId,
    required this.name,
    required this.phoneE164,
    this.isActive = true,
    this.priority = 1,
    this.isSynced = false,
    this.updatedAt,
  });

  /// Normalizes any input phone number to E.164 standard.
  /// Defaults to India (+91) if no country code is present.
  static String normalizePhone(String rawPhone, {String defaultCountryCode = '+91'}) {
    String cleaned = rawPhone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '');
    if (cleaned.startsWith('00')) {
      cleaned = '+${cleaned.substring(2)}';
    } else if (!cleaned.startsWith('+')) {
      if (cleaned.startsWith('0')) {
        cleaned = cleaned.substring(1);
      }
      final cc = defaultCountryCode.startsWith('+') ? defaultCountryCode : '+$defaultCountryCode';
      cleaned = '$cc$cleaned';
    }
    return cleaned;
  }

  ContactModel copyWith({
    int? id,
    int? remoteId,
    String? name,
    String? phoneE164,
    bool? isActive,
    int? priority,
    bool? isSynced,
    DateTime? updatedAt,
  }) {
    return ContactModel(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      name: name ?? this.name,
      phoneE164: phoneE164 ?? this.phoneE164,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      isSynced: isSynced ?? this.isSynced,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'remote_id': remoteId,
      'name': name,
      'phone_e164': phoneE164,
      'is_active': isActive ? 1 : 0,
      'priority': priority,
      'is_synced': isSynced ? 1 : 0,
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  factory ContactModel.fromMap(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'] as int?,
      remoteId: map['remote_id'] as int?,
      name: map['name'] as String? ?? '',
      phoneE164: map['phone_e164'] as String? ?? '',
      isActive: (map['is_active'] as int? ?? 1) == 1,
      priority: map['priority'] as int? ?? 1,
      isSynced: (map['is_synced'] as int? ?? 0) == 1,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'] as String) : null,
    );
  }

  factory ContactModel.fromRemoteJson(Map<String, dynamic> json) {
    return ContactModel(
      remoteId: json['id'] is int ? json['id'] as int : int.tryParse(json['id'].toString()),
      name: json['name'] as String? ?? '',
      phoneE164: json['phone_e164'] as String? ?? '',
      isActive: json['is_active'] == true || json['is_active'] == 1,
      priority: json['priority'] is int ? json['priority'] as int : int.tryParse(json['priority'].toString()) ?? 1,
      isSynced: true,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'] as String) : null,
    );
  }

  Map<String, dynamic> toRemoteJson() {
    return {
      'name': name,
      'phone_e164': phoneE164,
      'is_active': isActive,
      'priority': priority,
    };
  }
}

