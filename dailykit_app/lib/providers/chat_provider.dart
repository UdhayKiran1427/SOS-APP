import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_model.dart';
import '../models/contact_model.dart';
import '../services/database_helper.dart';
import '../services/sms_service.dart';

class ChatProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<ChatConversation> _conversations = [];
  List<ChatMessage> _activeMessages = [];
  ChatConversation? _activeChat;
  bool _isLoading = false;

  List<ChatConversation> get conversations => _conversations;
  List<ChatMessage> get activeMessages => _activeMessages;
  ChatConversation? get activeChat => _activeChat;
  bool get isLoading => _isLoading;

  ChatProvider() {
    loadConversations();
  }

  Future<void> loadConversations([List<ContactModel>? contacts]) async {
    _isLoading = true;
    notifyListeners();

    try {
      var list = await _db.getChats();

      // Auto-populate chat threads for saved emergency contacts if empty
      if (list.isEmpty && contacts != null && contacts.isNotEmpty) {
        for (final c in contacts) {
          await _db.getOrCreateChat(peerName: c.name, peerPhone: c.phoneE164);
        }
        list = await _db.getChats();
      }

      _conversations = list;
    } catch (e) {
      debugPrint('[ChatProvider] Error loading chats: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> openChat(ChatConversation chat) async {
    _activeChat = chat;
    _activeMessages = [];
    notifyListeners();

    await loadMessages(chat.id);
    await _db.markChatAsRead(chat.id);

    // Update unread badge in list
    final idx = _conversations.indexWhere((c) => c.id == chat.id);
    if (idx != -1) {
      _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  Future<void> loadMessages(String chatId) async {
    try {
      _activeMessages = await _db.getMessages(chatId);
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatProvider] Error loading messages: $e');
    }
  }

  Future<ChatConversation> startChatWithContact({
    required String name,
    required String phone,
  }) async {
    final chat = await _db.getOrCreateChat(peerName: name, peerPhone: phone);
    await loadConversations();
    return chat;
  }

  Future<void> sendMessage({
    required String content,
    String type = 'text',
    bool sendAsSms = false,
  }) async {
    if (_activeChat == null || content.trim().isEmpty) return;

    final msgId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${(1000 + DateTime.now().microsecond % 9000)}';
    final chat = _activeChat!;

    final message = ChatMessage(
      id: msgId,
      chatId: chat.id,
      senderId: 'me',
      content: content.trim(),
      type: type,
      status: 'pending',
      createdAt: DateTime.now(),
    );

    // 1. Immediately insert into local SQLite DB
    _activeMessages.add(message);
    notifyListeners();
    await _db.insertChatMessage(message);

    // Update conversation item
    _updateConversationLastMessage(chat.id, message.content, message.createdAt);

    // 2. If requested or emergency message, dispatch SMS via native SIM
    if (sendAsSms && chat.peerPhone.isNotEmpty) {
      try {
        await SmsService.instance.sendDirectSms(
          phone: chat.peerPhone,
          message: content.trim(),
        );
      } catch (e) {
        debugPrint('[ChatProvider] SMS dispatch error: $e');
      }
    }

    // 3. WhatsApp tick simulation (sent -> delivered -> read)
    Timer(const Duration(milliseconds: 400), () async {
      await _updateMsgStatus(msgId, 'sent');
    });

    Timer(const Duration(milliseconds: 1200), () async {
      await _updateMsgStatus(msgId, 'delivered');
    });

    Timer(const Duration(seconds: 3), () async {
      await _updateMsgStatus(msgId, 'read');
    });
  }

  Future<void> _updateMsgStatus(String messageId, String newStatus) async {
    final idx = _activeMessages.indexWhere((m) => m.id == messageId);
    if (idx != -1) {
      _activeMessages[idx] = _activeMessages[idx].copyWith(status: newStatus);
      notifyListeners();
      await _db.updateMessageStatus(messageId, newStatus);
    }
  }

  void _updateConversationLastMessage(String chatId, String message, DateTime time) {
    final idx = _conversations.indexWhere((c) => c.id == chatId);
    if (idx != -1) {
      final updated = _conversations[idx].copyWith(
        lastMessage: message,
        lastMessageTime: time,
      );
      _conversations.removeAt(idx);
      _conversations.insert(0, updated);
      notifyListeners();
    }
  }

  Future<void> deleteChat(String chatId) async {
    await _db.deleteChat(chatId);
    _conversations.removeWhere((c) => c.id == chatId);
    if (_activeChat?.id == chatId) {
      _activeChat = null;
      _activeMessages = [];
    }
    notifyListeners();
  }
}

