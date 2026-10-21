import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/chat_model.dart';
import '../../providers/chat_provider.dart';
import '../../services/location_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatConversation chat;

  const ChatDetailScreen({super.key, required this.chat});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isComposing = false;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().openChat(widget.chat);
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSend({String? customText, String type = 'text', bool sendAsSms = false}) async {
    final text = customText ?? _textController.text.trim();
    if (text.isEmpty) return;

    if (customText == null) {
      _textController.clear();
      setState(() => _isComposing = false);
    }

    final provider = context.read<ChatProvider>();
    await provider.sendMessage(
      content: text,
      type: type,
      sendAsSms: sendAsSms,
    );

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  Future<void> _shareLiveLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      final loc = await LocationService.instance.getSosLocation();
      final url = loc.googleMapsUrl.isNotEmpty
          ? loc.googleMapsUrl
          : 'https://maps.google.com/?q=${loc.latitude},${loc.longitude}';
      final acc = loc.accuracy != null ? ' (Accuracy: ±${loc.accuracy!.toStringAsFixed(1)}m)' : '';
      final text = '🚨 My Live Emergency Location:\n$url$acc';

      await _handleSend(
        customText: text,
        type: 'location',
        sendAsSms: true, // Also dispatches SMS to peer phone!
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not fetch location: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _callPeer() async {
    final uri = Uri.parse('tel:${widget.chat.peerPhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final chatProvider = context.watch<ChatProvider>();
    final messages = chatProvider.activeMessages;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                widget.chat.peerName.isNotEmpty ? widget.chat.peerName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chat.peerName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    widget.chat.peerPhone,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(160)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call_rounded),
            tooltip: 'Call Contact',
            onPressed: _callPeer,
          ),
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: 'Share Emergency Location',
            onPressed: _isGettingLocation ? null : _shareLiveLocation,
          ),
        ],
      ),
      body: Container(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFECE5DD),
        child: Column(
          children: [
            // Messages List
            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black45 : Colors.white70),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'No messages yet. Send a message or tap an emergency quick chip below!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return _buildMessageBubble(msg, theme, isDark);
                      },
                    ),
            ),

            // Quick Emergency Chips
            _buildQuickChips(theme, isDark),

            // Bottom Input Bar
            _buildInputBar(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChips(ThemeData theme, bool isDark) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ActionChip(
            avatar: _isGettingLocation
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, size: 14, color: Colors.blueAccent),
            label: const Text('📍 Send Location', style: TextStyle(fontSize: 12)),
            onPressed: _isGettingLocation ? null : _shareLiveLocation,
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
            label: const Text('🚨 Need Help ASAP!', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
            onPressed: () => _handleSend(customText: '🚨 EMERGENCY: I need help immediately! Please check on me.', sendAsSms: true),
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.phone_in_talk, size: 14, color: Colors.orange),
            label: const Text('📞 Call Me', style: TextStyle(fontSize: 12)),
            onPressed: () => _handleSend(customText: 'Please call me as soon as possible.', sendAsSms: true),
          ),
          const SizedBox(width: 6),
          ActionChip(
            avatar: const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
            label: const Text('🟢 I am safe', style: TextStyle(fontSize: 12)),
            onPressed: () => _handleSend(customText: 'I am safe now. Thank you!'),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg, ThemeData theme, bool isDark) {
    final isMe = msg.isMe;
    final timeStr = '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB)) // WhatsApp sender green
              : (isDark ? const Color(0xFF1F2C34) : Colors.white),          // WhatsApp receiver card
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location Card
            if (msg.type == 'location')
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : Colors.black.withAlpha(10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.map_rounded, color: Colors.red, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Google Maps Pin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Tap link to view location', style: TextStyle(fontSize: 11, color: isDark ? Colors.white60 : Colors.black54)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Content text
            Text(
              msg.content,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),

            // Timestamp and Status Tick
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildTickIcon(msg.status, isDark),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTickIcon(String status, bool isDark) {
    switch (status) {
      case 'pending':
        return Icon(Icons.access_time, size: 13, color: isDark ? Colors.white38 : Colors.black38);
      case 'sent':
        return Icon(Icons.check, size: 14, color: isDark ? Colors.white54 : Colors.black54);
      case 'delivered':
        return Icon(Icons.done_all, size: 15, color: isDark ? Colors.white54 : Colors.black54);
      case 'read':
        return const Icon(Icons.done_all, size: 15, color: Color(0xFF53BDEB)); // WhatsApp Blue Tick
      default:
        return const Icon(Icons.check, size: 14);
    }
  }

  Widget _buildInputBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Attach / SOS Options
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.blueAccent),
              tooltip: 'Attach Location / Action',
              onPressed: () => _showAttachMenu(context),
            ),

            // Text Input
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _textController,
                  textCapitalization: TextCapitalization.sentences,
                  minLines: 1,
                  maxLines: 4,
                  onChanged: (val) {
                    final composing = val.trim().isNotEmpty;
                    if (composing != _isComposing) {
                      setState(() => _isComposing = composing);
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: 'Message or emergency update...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),

            // Send Button
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.primary,
              child: IconButton(
                icon: Icon(
                  _isComposing ? Icons.send_rounded : Icons.my_location_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () {
                  if (_isComposing) {
                    _handleSend();
                  } else {
                    _shareLiveLocation();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.red,
                child: Icon(Icons.location_on, color: Colors.white),
              ),
              title: const Text('Share Live GPS Location'),
              subtitle: const Text('Sends current Google Maps link via SMS and in-app'),
              onTap: () {
                Navigator.of(ctx).pop();
                _shareLiveLocation();
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.amber,
                child: Icon(Icons.warning, color: Colors.white),
              ),
              title: const Text('Send Urgent SOS SMS'),
              subtitle: const Text('Directly dispatches emergency alert SMS to carrier'),
              onTap: () {
                Navigator.of(ctx).pop();
                _handleSend(
                  customText: '🚨 EMERGENCY ALERT: I require immediate assistance. Please reach out to me urgently.',
                  sendAsSms: true,
                );
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.green,
                child: Icon(Icons.check, color: Colors.white),
              ),
              title: const Text('Status: "I am Safe"'),
              subtitle: const Text('Let this contact know everything is okay'),
              onTap: () {
                Navigator.of(ctx).pop();
                _handleSend(customText: 'Status update: I have reached safely and I am okay now.');
              },
            ),
          ],
        ),
      ),
    );
  }
}

