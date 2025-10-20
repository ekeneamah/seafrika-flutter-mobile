import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Service for managing message drafts
///
/// Features:
/// - Auto-save drafts (debounced 2 seconds after typing stops)
/// - Local storage (SharedPreferences) for offline access
/// - Server sync for cross-device access
/// - Auto-delete drafts older than 7 days (server-side)
class DraftsApiService {
  final _storage = const FlutterSecureStorage();
  final http.Client _client;
  final String baseUrl;

  // Debounce timer for auto-save
  Timer? _saveTimer;
  static const Duration _debounceDuration = Duration(seconds: 2);

  // Local storage key prefix
  static const String _localDraftPrefix = 'draft_';

  DraftsApiService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _client = client ?? http.Client();

  /// Get auth token from storage
  Future<String?> _getAuthToken() async {
    return await _storage.read(key: 'auth_token');
  }

  /// Save draft with debounce (auto-save 2s after typing stops)
  ///
  /// This is the main method to call when user types.
  /// It will automatically debounce and save both locally and to server.
  Future<void> saveDraftDebounced({
    required String conversationId,
    required String text,
    List<Map<String, String>>? attachments,
  }) async {
    // Cancel previous timer
    _saveTimer?.cancel();

    // Start new timer
    _saveTimer = Timer(_debounceDuration, () {
      saveDraft(
        conversationId: conversationId,
        text: text,
        attachments: attachments,
      );
    });
  }

  /// Save draft immediately (both local and server)
  Future<DraftResult> saveDraft({
    required String conversationId,
    required String text,
    List<Map<String, String>>? attachments,
  }) async {
    try {
      debugPrint('💾 Saving draft for conversation: $conversationId');

      // Save locally first (for offline access)
      await _saveLocalDraft(conversationId, text, attachments);

      // Then sync to server
      final token = await _getAuthToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await _client.post(
        Uri.parse('$baseUrl/messages/drafts/$conversationId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'text': text,
          'attachments': attachments ?? [],
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Draft saved to server');
        return DraftResult.fromJson(data['draft']);
      } else {
        final error = jsonDecode(response.body);
        debugPrint(
            '⚠️ Failed to sync draft to server: ${error['message'] ?? 'Unknown error'}');
        // Local draft is still saved, so don't throw error
        return DraftResult(
          conversationId: conversationId,
          text: text,
          attachments: attachments ?? [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    } catch (e) {
      debugPrint('❌ Error saving draft: $e');
      // Return local draft result even if server sync fails
      return DraftResult(
        conversationId: conversationId,
        text: text,
        attachments: attachments ?? [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Get draft for a conversation
  ///
  /// Returns local draft if server is unreachable
  Future<DraftResult?> getDraft(String conversationId) async {
    try {
      debugPrint('📖 Getting draft for conversation: $conversationId');

      final token = await _getAuthToken();
      if (token == null) {
        // Try local draft
        return await _getLocalDraft(conversationId);
      }

      final response = await _client.get(
        Uri.parse('$baseUrl/messages/drafts/$conversationId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['draft'] != null) {
          debugPrint('✅ Draft loaded from server');
          final draft = DraftResult.fromJson(data['draft']);
          // Update local cache
          await _saveLocalDraft(conversationId, draft.text, draft.attachments);
          return draft;
        }
      }

      // Fallback to local draft
      return await _getLocalDraft(conversationId);
    } catch (e) {
      debugPrint('❌ Error getting draft: $e');
      // Fallback to local draft
      return await _getLocalDraft(conversationId);
    }
  }

  /// Delete draft (after message sent or user clears)
  Future<void> deleteDraft(String conversationId) async {
    try {
      debugPrint('🗑️ Deleting draft for conversation: $conversationId');

      // Delete locally first
      await _deleteLocalDraft(conversationId);

      // Then delete from server
      final token = await _getAuthToken();
      if (token == null) {
        return; // Local draft deleted, that's good enough
      }

      final response = await _client.delete(
        Uri.parse('$baseUrl/messages/drafts/$conversationId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        debugPrint('✅ Draft deleted from server');
      }
    } catch (e) {
      debugPrint('❌ Error deleting draft: $e');
      // Local draft is deleted, so consider this successful
    }
  }

  /// Get all drafts (for conversation list indicators)
  Future<List<DraftResult>> getAllDrafts() async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        // Return local drafts
        return await _getAllLocalDrafts();
      }

      final response = await _client.get(
        Uri.parse('$baseUrl/messages/drafts'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> draftsJson = data['drafts'] ?? [];
        return draftsJson.map((json) => DraftResult.fromJson(json)).toList();
      }

      // Fallback to local drafts
      return await _getAllLocalDrafts();
    } catch (e) {
      debugPrint('❌ Error getting all drafts: $e');
      return await _getAllLocalDrafts();
    }
  }

  // ============================================
  // LOCAL STORAGE (SharedPreferences) METHODS
  // ============================================

  /// Save draft locally
  Future<void> _saveLocalDraft(
    String conversationId,
    String text,
    List<Map<String, String>>? attachments,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftData = {
        'text': text,
        'attachments': attachments ?? [],
        'updatedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(
        '$_localDraftPrefix$conversationId',
        jsonEncode(draftData),
      );
      debugPrint('💾 Draft saved locally for $conversationId');
    } catch (e) {
      debugPrint('❌ Error saving local draft: $e');
    }
  }

  /// Get local draft
  Future<DraftResult?> _getLocalDraft(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftJson = prefs.getString('$_localDraftPrefix$conversationId');

      if (draftJson == null) {
        return null;
      }

      final draftData = jsonDecode(draftJson);
      debugPrint('📖 Draft loaded from local storage for $conversationId');

      return DraftResult(
        conversationId: conversationId,
        text: draftData['text'] ?? '',
        attachments: List<Map<String, String>>.from(
          (draftData['attachments'] ?? [])
              .map((a) => Map<String, String>.from(a)),
        ),
        createdAt: DateTime.parse(draftData['updatedAt']),
        updatedAt: DateTime.parse(draftData['updatedAt']),
      );
    } catch (e) {
      debugPrint('❌ Error getting local draft: $e');
      return null;
    }
  }

  /// Delete local draft
  Future<void> _deleteLocalDraft(String conversationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_localDraftPrefix$conversationId');
      debugPrint('🗑️ Local draft deleted for $conversationId');
    } catch (e) {
      debugPrint('❌ Error deleting local draft: $e');
    }
  }

  /// Get all local drafts
  Future<List<DraftResult>> _getAllLocalDrafts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final drafts = <DraftResult>[];

      for (final key in keys) {
        if (key.startsWith(_localDraftPrefix)) {
          final conversationId = key.substring(_localDraftPrefix.length);
          final draft = await _getLocalDraft(conversationId);
          if (draft != null) {
            drafts.add(draft);
          }
        }
      }

      return drafts;
    } catch (e) {
      debugPrint('❌ Error getting all local drafts: $e');
      return [];
    }
  }

  /// Cancel any pending save timers
  void dispose() {
    _saveTimer?.cancel();
  }
}

/// Draft result model
class DraftResult {
  final String conversationId;
  final String text;
  final List<Map<String, String>> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  DraftResult({
    required this.conversationId,
    required this.text,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory DraftResult.fromJson(Map<String, dynamic> json) {
    return DraftResult(
      conversationId: json['conversationId'] ?? '',
      text: json['text'] ?? '',
      attachments: List<Map<String, String>>.from(
        (json['attachments'] ?? []).map((a) => Map<String, String>.from(a)),
      ),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversationId': conversationId,
      'text': text,
      'attachments': attachments,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Check if draft is empty
  bool get isEmpty => text.trim().isEmpty && attachments.isEmpty;

  /// Check if draft is not empty
  bool get isNotEmpty => !isEmpty;
}
