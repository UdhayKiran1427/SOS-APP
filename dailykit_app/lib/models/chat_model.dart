class ChatConversation {
  final String id;
  final String peerId;
  final String peerName;
  final String peerPhone;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  ChatConversation({
    required this.id,
    required this.peerId,
    required this.peerName,
    required this.peerPhone,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  factory ChatConversation.fromMap(Map<String, dynamic> map) {
    return ChatConversation(
      id: map['id'] as String,
      peerId: map['peer_id'] as String,
      peerName: map['peer_name'] as String,
      peerPhone: map['peer_phone'] as String,
      lastMessage: map['last_message'] as String?,
      lastMessageTime: map['last_message_time'] != null
          ? DateTime.tryParse(map['last_message_time'] as String)
          : null,
      unreadCount: (map['unread_count'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'peer_id': peerId,
      'peer_name': peerName,
      'peer_phone': peerPhone,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime?.toIso8601String(),
      'unread_count': unreadCount,
    };
  }

  ChatConversation copyWith({
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return ChatConversation(
      id: id,
      peerId: peerId,
      peerName: peerName,
      peerPhone: peerPhone,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final String type; // 'text', 'location', 'sos_alert', 'image'
  final String status; // 'pending', 'sent', 'delivered', 'read'
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    this.type = 'text',
    this.status = 'sent',
    required this.createdAt,
  });

  bool get isMe => senderId == 'me';

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] as String,
      chatId: map['chat_id'] as String,
      senderId: map['sender_id'] as String,
      content: map['content'] as String,
      type: (map['type'] as String?) ?? 'text',
      status: (map['status'] as String?) ?? 'sent',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chat_id': chatId,
      'sender_id': senderId,
      'content': content,
      'type': type,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  ChatMessage copyWith({
    String? status,
    String? content,
  }) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      senderId: senderId,
      content: content ?? this.content,
      type: type,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

