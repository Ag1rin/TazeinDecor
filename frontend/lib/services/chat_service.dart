// Chat Service
import 'api_service.dart';
// ignore: unused_import
import 'dart:io';

class ChatMessage {
  final int id;
  final int userId;
  final String userName;
  final String? message;
  final String? imageUrl;
  final String? voiceUrl;
  final String messageType;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.userName,
    this.message,
    this.imageUrl,
    this.voiceUrl,
    required this.messageType,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'],
      message: json['message'],
      imageUrl: json['image_url'],
      voiceUrl: json['voice_url'],
      messageType: json['message_type'] ?? 'text',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class ChatService {
  final ApiService _api = ApiService();

  Future<List<ChatMessage>> getMessages({int limit = 100}) async {
    try {
      final response = await _api.get(
        '/chat',
        queryParameters: {'limit': limit},
      );
      if (response.statusCode == 200) {
        return (response.data as List)
            .map((json) => ChatMessage.fromJson(json))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<ChatMessage?> sendMessage(String message) async {
    try {
      final response = await _api.post(
        '/chat',
        data: {'message': message, 'message_type': 'text'},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ChatMessage.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ChatMessage?> sendImage(String imagePath) async {
    try {
      final response = await _api.postFile('/chat/image', imagePath);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ChatMessage.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ChatMessage?> sendVoice(String voicePath) async {
    try {
      final response = await _api.postFile('/chat/voice', voicePath);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return ChatMessage.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<ChatMessage?> deleteMessage(int messageId) async {
    try {
      final response = await _api.delete('/chat/$messageId');
      if (response.statusCode == 200 && response.data != null) {
        return ChatMessage.fromJson(response.data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
