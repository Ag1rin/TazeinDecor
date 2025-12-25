// WebSocket Service for Real-time Chat
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import 'chat_service.dart';

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<ChatMessage> _messageController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<ChatMessage> _updateController =
      StreamController<ChatMessage>.broadcast();
  bool _isConnected = false;

  Stream<ChatMessage> get messageStream => _messageController.stream;
  Stream<ChatMessage> get updateStream => _updateController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      final authService = AuthService();
      final token = await authService.getToken();

      if (token == null) {
        throw Exception('No authentication token');
      }

      // Convert http to ws
      final wsUrl = AppConfig.baseUrl
          .replaceFirst('http://', 'ws://')
          .replaceFirst('https://', 'wss://');

      _channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl${AppConfig.apiVersion}/chat/ws?token=$token'),
      );

      _isConnected = true;

      // Listen for messages
      _channel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> jsonData = data is String
                ? Map<String, dynamic>.from(jsonDecode(data))
                : Map<String, dynamic>.from(data);

            if (jsonData['type'] == 'new_message') {
              // Convert to ChatMessage format
              final message = ChatMessage(
                id: jsonData['id'] as int,
                userId: jsonData['user_id'] as int,
                userName: jsonData['user_name'] as String,
                message: jsonData['message'] as String?,
                imageUrl: jsonData['image_url'] as String?,
                voiceUrl: jsonData['voice_url'] as String?,
                messageType: jsonData['message_type'] as String? ?? 'text',
                createdAt: DateTime.parse(jsonData['created_at'] as String),
              );
              _messageController.add(message);
            } else if (jsonData['type'] == 'message_deleted') {
              final updated = jsonData['updated_message'] as Map<String, dynamic>?;
              if (updated != null) {
                _updateController.add(
                  ChatMessage.fromJson(updated),
                );
              }
            }
          } catch (e) {
            debugPrint('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          _isConnected = false;
        },
        onDone: () {
          _isConnected = false;
        },
      );
    } catch (e) {
      debugPrint('Error connecting WebSocket: $e');
      _isConnected = false;
      rethrow;
    }
  }

  Future<void> sendMessage(String message) async {
    if (!_isConnected || _channel == null) {
      await connect();
    }

    _channel?.sink.add(
      jsonEncode({
        'type': 'send_message',
        'message': message,
        'message_type': 'text',
      }),
    );
  }

  Future<void> sendImage(String imageUrl) async {
    if (!_isConnected || _channel == null) {
      await connect();
    }

    _channel?.sink.add(
      jsonEncode({
        'type': 'send_message',
        'image_url': imageUrl,
        'message_type': 'image',
      }),
    );
  }

  Future<void> sendVoice(String voiceUrl) async {
    if (!_isConnected || _channel == null) {
      await connect();
    }

    _channel?.sink.add(
      jsonEncode({
        'type': 'send_message',
        'voice_url': voiceUrl,
        'message_type': 'voice',
      }),
    );
  }

  Future<void> deleteMessage(int messageId) async {
    if (!_isConnected || _channel == null) {
      await connect();
    }

    _channel?.sink.add(
      jsonEncode({'type': 'delete_message', 'message_id': messageId}),
    );
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _updateController.close();
  }
}
