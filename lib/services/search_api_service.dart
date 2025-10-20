import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../config/api_config.dart';

/// API service for message search functionality
class SearchApiService {
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

  /// Search messages within a specific conversation
  Future<Map<String, dynamic>> searchMessages({
    required String conversationId,
    required String query,
    int limit = 50,
    int page = 0,
  }) async {
    try {
      final token = await _getIdToken();

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/search/chat-search?conversationId=$conversationId&query=${Uri.encodeComponent(query)}&limit=$limit&page=$page',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Search failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Search error: $e');
    }
  }

  /// Search messages across all conversations for a business
  Future<Map<String, dynamic>> searchBusinessMessages({
    required String businessId,
    required String query,
    int limit = 50,
    int page = 0,
  }) async {
    try {
      final token = await _getIdToken();

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/search/chat-search/business/$businessId?query=${Uri.encodeComponent(query)}&limit=$limit&page=$page',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Business search failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Business search error: $e');
    }
  }

  /// Trigger manual indexing of messages
  Future<Map<String, dynamic>> indexMessages({
    String? conversationId,
    String? businessId,
    List<String>? messageIds,
  }) async {
    try {
      final token = await _getIdToken();

      final url = Uri.parse('${ApiConfig.baseUrl}/search/chat-search/index');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          if (conversationId != null) 'conversationId': conversationId,
          if (businessId != null) 'businessId': businessId,
          if (messageIds != null) 'messageIds': messageIds,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Indexing failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Indexing error: $e');
    }
  }

  /// Get search suggestions based on partial query
  Future<List<String>> getSuggestions({
    required String query,
    String? businessId,
  }) async {
    try {
      final token = await _getIdToken();

      final url = Uri.parse(
        '${ApiConfig.baseUrl}/search/chat-search/suggestions?query=${Uri.encodeComponent(query)}${businessId != null ? '&businessId=$businessId' : ''}',
      );

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<String>.from(data['suggestions'] ?? []);
      } else {
        throw Exception(
          'Get suggestions failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Get suggestions error: $e');
    }
  }

  /// Reindex all messages (admin only)
  Future<Map<String, dynamic>> reindexAll() async {
    try {
      final token = await _getIdToken();

      final url = Uri.parse('${ApiConfig.baseUrl}/search/chat-search/reindex');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body);
      } else {
        throw Exception(
          'Reindex failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Reindex error: $e');
    }
  }
}
