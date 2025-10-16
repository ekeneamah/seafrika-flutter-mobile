import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

/// Service for managing message reactions via backend API
class ReactionsApiService {
  final String baseUrl = ApiConfig.baseUrl;
  final AuthService _authService = AuthService();

  /// Add a reaction to a message
  Future<Map<String, dynamic>> addReaction({
    required String messageId,
    required String userId,
    required String businessId,
    required String emoji,
    String? userName,
    String? platform,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/messages/$messageId/reactions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'userId': userId,
          'businessId': businessId,
          'emoji': emoji,
          'userName': userName,
          'platform': platform ?? 'app',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Reaction added: $emoji');
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to add reaction: ${error['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error adding reaction: $e');
      rethrow;
    }
  }

  /// Remove a reaction from a message
  Future<void> removeReaction({
    required String messageId,
    required String reactionId,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/messages/$messageId/reactions/$reactionId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Reaction removed');
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to remove reaction: ${error['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error removing reaction: $e');
      rethrow;
    }
  }

  /// Get all reactions for a message
  Future<List<Map<String, dynamic>>> getReactions({
    required String messageId,
  }) async {
    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Authentication required');
      }

      final response = await http.post(
        Uri.parse('$baseUrl/messages/$messageId/reactions/list'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> reactions = data['reactions'] ?? [];
        debugPrint('✅ Retrieved ${reactions.length} reactions');
        return reactions.cast<Map<String, dynamic>>();
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Failed to get reactions: ${error['message']}');
      }
    } catch (e) {
      debugPrint('❌ Error getting reactions: $e');
      rethrow;
    }
  }
}
