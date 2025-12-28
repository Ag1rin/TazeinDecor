// Chat Room Screen
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../utils/app_colors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../../services/websocket_service.dart';
import '../../config/app_config.dart';
import 'package:intl/intl.dart';

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({super.key});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  WebSocketService? _wsService;
  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<ChatMessage>? _updateSubscription;

  List<ChatMessage> _messages = [];
  final bool _isLoading = false;
  // ignore: unused_field
  final bool _isRecording = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _initWebSocket();
    _loadMessages();
  }

  Future<void> _initWebSocket() async {
    try {
      _wsService = WebSocketService();
      await _wsService!.connect();

      setState(() {
        _isConnected = true;
      });

      // Listen for new messages
      _messageSubscription = _wsService!.messageStream.listen((message) {
        setState(() {
          _messages.add(message);
        });
        _scrollToBottom();
      });

      // Listen for message updates (delete -> system replacement)
      _updateSubscription = _wsService!.updateStream.listen((updatedMessage) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == updatedMessage.id);
          if (index != -1) {
            _messages[index] = updatedMessage;
          }
        });
      });
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
      // Fallback to polling if WebSocket fails
      _startPolling();
    }
  }

  void _startPolling() {
    // Poll for new messages every 2 seconds (fallback)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && !_isConnected) {
        _loadMessages();
        _startPolling();
      }
    });
  }

  Future<void> _loadMessages() async {
    final messages = await _chatService.getMessages();
    if (mounted) {
      setState(() {
        _messages = messages;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final message = _messageController.text.trim();
    _messageController.clear();

    if (_isConnected && _wsService != null) {
      // Use WebSocket for real-time
      await _wsService!.sendMessage(message);
    } else {
      // Fallback to HTTP
      final sentMessage = await _chatService.sendMessage(message);
      if (sentMessage != null) {
        _loadMessages();
      }
    }
  }

  Future<void> _playVoice(String? voiceUrl) async {
    if (voiceUrl == null) return;
    // Play voice message
    // Implementation depends on your backend URL structure
    try {
      await _audioPlayer.play(
        UrlSource('${AppConfig.baseUrl}/uploads/$voiceUrl'),
      );
    } catch (e) {
      Fluttertoast.showToast(msg: 'خطا در پخش صدا');
    }
  }

  Future<void> _deleteMessage(int messageId) async {
    if (_isConnected && _wsService != null) {
      await _wsService!.deleteMessage(messageId);
    } else {
      final updated = await _chatService.deleteMessage(messageId);
      if (updated != null) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == updated.id);
          if (index != -1) {
            _messages[index] = updated;
          }
        });
      } else {
        Fluttertoast.showToast(msg: 'خطا در حذف پیام');
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    _messageSubscription?.cancel();
    _updateSubscription?.cancel();
    _wsService?.dispose();
    super.dispose();
  }

  String _filterMobileNumbers(String? text) {
    if (text == null) return '';
    // Replace Iranian mobile numbers (09xxxxxxxxx) with stars
    return text.replaceAll(RegExp(r'09\d{9}'), '***********');
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final canDelete =
        authProvider.user?.isAdmin == true ||
        authProvider.user?.isOperator == true ||
        authProvider.user?.isModerator == true;

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('چت روم')),
        body: Column(
          children: [
            // Messages list
            Expanded(
              child: _isLoading && _messages.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? const Center(child: Text('پیامی وجود ندارد'))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final isMe = message.userId == authProvider.user?.id;
                        return _buildMessageBubble(message, isMe, canDelete);
                      },
                    ),
            ),
            // Input area
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Image button (disabled - grayed out)
                  IconButton(
                    icon: const Icon(Icons.image),
                    color: Colors.grey,
                    onPressed: null,
                  ),
                  // Voice button (disabled - grayed out)
                  IconButton(
                    icon: const Icon(Icons.mic_none),
                    color: Colors.grey,
                    onPressed: null,
                  ),
                  // Text input
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'پیام...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  // Send button
                  IconButton(
                    icon: const Icon(Icons.send),
                    color: AppColors.primaryBlue,
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final localTime = dateTime.toLocal();

    if (messageDate.isAtSameMomentAs(today)) {
      return DateFormat('HH:mm').format(localTime);
    } else if (messageDate.isAtSameMomentAs(
      today.subtract(const Duration(days: 1)),
    )) {
      return 'دیروز ${DateFormat('HH:mm').format(localTime)}';
    } else {
      return DateFormat('MM/dd HH:mm').format(localTime);
    }
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe, bool canDelete) {
    final isSystem = message.messageType == 'system';
    final bubbleColor = isSystem
        ? Colors.grey[200]
        : (isMe ? AppColors.primaryBlue : Colors.grey[300]);
    final textColor = isSystem
        ? Colors.black87
        : (isMe ? Colors.white : Colors.black87);

    return Align(
      alignment: isSystem
          ? Alignment.center
          : (isMe ? Alignment.centerRight : Alignment.centerLeft),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: isSystem
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            if (!isSystem)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      message.userName,
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (canDelete)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteMessage(message.id);
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'delete', child: Text('حذف پیام')),
                      ],
                      child: const Icon(
                        Icons.more_vert,
                        size: 18,
                        color: Colors.black54,
                      ),
                    ),
                ],
              ),
            if (isSystem)
              Text(
                message.message ?? 'This message was deleted by an admin.',
                style: const TextStyle(
                  color: Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              )
            else if (message.messageType == 'text' && message.message != null)
              Text(
                _filterMobileNumbers(message.message),
                style: TextStyle(color: textColor),
              )
            else if (message.messageType == 'image' && message.imageUrl != null)
              CachedNetworkImage(
                imageUrl: '${AppConfig.baseUrl}/uploads/${message.imageUrl}',
                fit: BoxFit.cover,
                width: 200,
                height: 200,
              )
            else if (message.messageType == 'voice' && message.voiceUrl != null)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _playVoice(message.voiceUrl),
                  ),
                  const Text('پیام صوتی'),
                ],
              ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _formatTimestamp(message.createdAt),
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFAAAAAA)
                      : const Color(0xFF666666),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
