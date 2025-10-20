import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/message.dart';

class ThreadsApiService {
  final String baseUrl = ApiConfig.baseUrl;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  /// Get authentication token from secure storage
  Future<String?> _getAuthToken() async {
    return await _storage.read(key: 'auth_token');
  }

  /// Reply to a specific message
  Future<Message> replyToMessage({
    required String parentMessageId,
    required String conversationId,
    required String content,
    required String senderId,
    String? platform,
    List<MessageAttachment>? attachments,
  }) async {
    try {
      final token = await _getAuthToken();
      
      final response = await http.post(
        Uri.parse('$baseUrl/messages/threads/reply'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'parentMessageId': parentMessageId,
          'conversationId': conversationId,
          'content': content,
          'senderId': senderId,
          'platform': platform ?? 'app',
          'attachments': attachments?.map((a) => {
            'type': a.type,
            'url': a.url,
            'thumbnailUrl': a.thumbnailUrl,
            'filename': a.filename,
          }).toList(),
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return Message.fromMap({
          'id': data['message']['id'],
          ...data['message'],
        });
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to send reply');
      }
    } catch (e) {
      print('Error sending reply: $e');
      rethrow;
    }
  }

  /// Get all messages in a thread
  Future<ThreadResponse> getThreadMessages(String messageId) async {
    try {
      final token = await _getAuthToken();
      
      final response = await http.get(
        Uri.parse('$baseUrl/messages/threads/$messageId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ThreadResponse.fromJson(data);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to get thread messages');
      }
    } catch (e) {
      print('Error getting thread messages: $e');
      rethrow;
    }
  }

  /// Get thread preview (parent message info)
  Future<ThreadPreview?> getThreadPreview(String messageId) async {
    try {
      final token = await _getAuthToken();
      
      final response = await http.get(
        Uri.parse('$baseUrl/messages/threads/$messageId/preview'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data == null) return null;
        return ThreadPreview.fromJson(data);
      } else {
        return null;
      }
    } catch (e) {
      print('Error getting thread preview: $e');
      return null;
    }
  }

  /// Delete a reply message
  Future<void> deleteReply(String messageId) async {
    try {
      final token = await _getAuthToken();
      
      final response = await http.delete(
        Uri.parse('$baseUrl/messages/threads/$messageId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode != 204) {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to delete reply');
      }
    } catch (e) {
      print('Error deleting reply: $e');
      rethrow;
    }
  }
}

/// Thread response data model
class ThreadResponse {
  final String parentMessageId;
  final int replyCount;
  final int threadDepth;
  final List<Message> messages;

  ThreadResponse({
    required this.parentMessageId,
    required this.replyCount,
    required this.threadDepth,
    required this.messages,
  });

  factory ThreadResponse.fromJson(Map<String, dynamic> json) {
    return ThreadResponse(
      parentMessageId: json['parentMessageId'],
      replyCount: json['replyCount'] ?? 0,
      threadDepth: json['threadDepth'] ?? 0,
      messages: (json['messages'] as List?)
          ?.map((m) => Message.fromMap(m))
          .toList() ?? [],
    );
  }
}

/// Thread preview data model
class ThreadPreview {
  final String id;
  final String content;
  final String senderId;
  final DateTime createdAt;

  ThreadPreview({
    required this.id,
    required this.content,
    required this.senderId,
    required this.createdAt,
  });

  factory ThreadPreview.fromJson(Map<String, dynamic> json) {
    return ThreadPreview(
      id: json['id'],
      content: json['content'] ?? '',
      senderId: json['senderId'],
      createdAt: json['createdAt'] is String
          ? DateTime.parse(json['createdAt'])
          : (json['createdAt'] as Map)['_seconds'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                  json['createdAt']['_seconds'] * 1000)
              : DateTime.now(),
    );
  }
}
