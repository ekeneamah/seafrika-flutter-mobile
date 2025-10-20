import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

/// Service for bulk message operations
class BulkMessageApiService {
  final String baseUrl = ApiConfig.baseUrl;

  /// Get the current user's ID token
  Future<String> _getIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw Exception('Failed to obtain ID token');
    }
    return idToken;
  }

  /// Delete multiple messages
  Future<Map<String, dynamic>> deleteMessages({
    required List<String> messageIds,
    required String conversationId,
    required String businessId,
    bool deleteForEveryone = false,
  }) async {
    try {
      final token = await _getIdToken();

      final response = await http.post(
        Uri.parse('$baseUrl/messages/bulk/delete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messageIds': messageIds,
          'conversationId': conversationId,
          'businessId': businessId,
          'deleteForEveryone': deleteForEveryone,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Deleted ${messageIds.length} messages');
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to delete messages: ${error['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error deleting messages: $e');
      rethrow;
    }
  }

  /// Mark multiple messages as read
  Future<Map<String, dynamic>> markAsRead({
    required List<String> messageIds,
    required String conversationId,
  }) async {
    try {
      final token = await _getIdToken();

      final response = await http.post(
        Uri.parse('$baseUrl/messages/bulk/mark-read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messageIds': messageIds,
          'conversationId': conversationId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Marked ${messageIds.length} messages as read');
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to mark messages as read: ${error['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error marking messages as read: $e');
      rethrow;
    }
  }

  /// Copy message text from multiple messages
  /// This is a client-side operation that fetches message content
  Future<String> copyMessages({
    required List<Map<String, dynamic>> messages,
  }) async {
    try {
      final buffer = StringBuffer();

      for (var i = 0; i < messages.length; i++) {
        final message = messages[i];
        final senderName = message['senderName'] ?? 'Unknown';
        final text = message['text'] ?? '';
        final timestamp = message['timestamp'] ?? '';

        buffer.writeln('[$senderName - $timestamp]');
        buffer.writeln(text);

        if (i < messages.length - 1) {
          buffer.writeln();
        }
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('❌ Error copying messages: $e');
      rethrow;
    }
  }

  /// Forward multiple messages
  Future<Map<String, dynamic>> forwardMessages({
    required List<String> messageIds,
    required String sourceConversationId,
    required List<String> targetConversationIds,
    required String businessId,
    bool withQuote = false,
  }) async {
    try {
      final token = await _getIdToken();

      final response = await http.post(
        Uri.parse('$baseUrl/messages/bulk/forward'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messageIds': messageIds,
          'sourceConversationId': sourceConversationId,
          'targetConversationIds': targetConversationIds,
          'businessId': businessId,
          'withQuote': withQuote,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Forwarded ${messageIds.length} messages');
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to forward messages: ${error['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error forwarding messages: $e');
      rethrow;
    }
  }

  /// Export selected messages to a file format
  Future<Map<String, dynamic>> exportMessages({
    required List<String> messageIds,
    required String conversationId,
    String format = 'json', // json, txt, csv
  }) async {
    try {
      final token = await _getIdToken();

      final response = await http.post(
        Uri.parse('$baseUrl/messages/bulk/export'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messageIds': messageIds,
          'conversationId': conversationId,
          'format': format,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Exported ${messageIds.length} messages');
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to export messages: ${error['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error exporting messages: $e');
      rethrow;
    }
  }
}
