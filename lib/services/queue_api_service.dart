import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

/// Service for calling backend queue API endpoints
class QueueApiService {
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

  /// Queue a message via backend API
  Future<Map<String, dynamic>> queueMessage({
    required String messageId,
    required String conversationId,
    required String businessId,
    required String integrationId,
    required String platform,
    required String recipientId,
    String? message,
    String? messageType,
    String? attachmentUrl,
    Map<String, dynamic>? metadata,
    String? reason,
  }) async {
    try {
      final token = await _getIdToken();

      final response = await http.post(
        Uri.parse('$baseUrl/messages/queue'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messageId': messageId,
          'conversationId': conversationId,
          'businessId': businessId,
          'integrationId': integrationId,
          'platform': platform,
          'recipientId': recipientId,
          'message': message,
          'messageType': messageType,
          'attachmentUrl': attachmentUrl,
          'metadata': metadata,
          'reason': reason,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Message queued via API: ${data['id']}');
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to queue message: ${error['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error queuing message via API: $e');
      rethrow;
    }
  }

  /// Manually retry a queued message
  Future<Map<String, dynamic>> retryMessage(String queueId) async {
    try {
      final token = await _getIdToken();

      final response = await http.post(
        Uri.parse('$baseUrl/messages/queue/$queueId/retry'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Message retry result: ${data['message']}');
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to retry message: ${error['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error retrying message via API: $e');
      rethrow;
    }
  }

  /// Get all queued messages for a business
  Future<List<Map<String, dynamic>>> getBusinessQueue(String businessId) async {
    try {
      final token = await _getIdToken();

      final response = await http.get(
        Uri.parse('$baseUrl/messages/queue/business/$businessId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('✅ Retrieved ${data.length} queued messages');
        return data.cast<Map<String, dynamic>>();
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to get queue: ${error['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error getting business queue via API: $e');
      rethrow;
    }
  }

  /// Get queued messages for a specific conversation
  Future<List<Map<String, dynamic>>> getConversationQueue(
      String conversationId) async {
    try {
      final token = await _getIdToken();

      final response = await http.get(
        Uri.parse('$baseUrl/messages/queue/conversation/$conversationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint(
            '✅ Retrieved ${data.length} queued messages for conversation');
        return data.cast<Map<String, dynamic>>();
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to get queue: ${error['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error getting conversation queue via API: $e');
      rethrow;
    }
  }
}
