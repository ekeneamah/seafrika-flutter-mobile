import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:vendor_app/models/integration.dart';
import 'package:crypto/crypto.dart';
import 'package:vendor_app/config/collection_references.dart';
import 'package:vendor_app/config/api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Exception types for integration operations
class IntegrationException implements Exception {
  final String message;
  final String code;

  const IntegrationException(this.message, this.code);

  @override
  String toString() => 'IntegrationException: $message (Code: $code)';
}

class IntegrationService {
  final String _businessId;

  /// Expose API base URL for callers that need to build integration API endpoints
  String get baseUrl => ApiConfig.baseUrl;

  /// Compatibility method used by UI callers to retrieve an access token for
  /// backend integration API calls. Returns the current Firebase ID token.
  Future<String> getUserIdToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw IntegrationException('User not authenticated', 'AUTH_REQUIRED');
    }
    final idToken = await user.getIdToken();
    if (idToken == null || idToken.isEmpty) {
      throw IntegrationException(
          'Failed to obtain ID token', 'TOKEN_UNAVAILABLE');
    }
    return idToken;
  }

  // Encryption key for credentials (in production, this should come from secure storage)
  static const String _encryptionKey = 'vendor_app_integration_key_2024';

  IntegrationService({
    required FirebaseFirestore firestore,
    required String businessId,
  }) : _businessId = businessId;

  /// Create default settings based on platform category
  IntegrationSettings _createDefaultSettings(String category) {
    switch (category) {
      case 'ecommerce':
      case 'marketplace':
        return IntegrationSettings(
          autoSync: false,
          syncInterval: 30,
          syncInventory: true,
          syncOrders: true,
          syncProducts: true,
          // Review settings (off for ecommerce/marketplace)
          syncReviews: false,
          syncRatings: false,
          autoRespondReviews: false,
          notifyNewReviews: false,
          syncCustomerFeedback: false,
        );
      case 'payment':
        return IntegrationSettings(
          autoSync: false,
          syncInterval: 15,
          syncInventory: false,
          syncOrders: true,
          syncProducts: false,
          // Review settings (off for payment platforms)
          syncReviews: false,
          syncRatings: false,
          autoRespondReviews: false,
          notifyNewReviews: false,
          syncCustomerFeedback: false,
        );
      case 'social':
        return IntegrationSettings(
          autoSync: false,
          syncInterval: 60,
          syncInventory: false,
          syncOrders: false,
          syncProducts: true,
          // Review settings (off for social platforms)
          syncReviews: false,
          syncRatings: false,
          autoRespondReviews: false,
          notifyNewReviews: false,
          syncCustomerFeedback: false,
        );
      case 'messaging':
        return IntegrationSettings(
          autoSync: true,
          syncInterval: 5, // More frequent for messaging
          syncInventory: false,
          syncOrders: false,
          syncProducts: false,
          // Review settings (off for messaging platforms)
          syncReviews: false,
          syncRatings: false,
          autoRespondReviews: false,
          notifyNewReviews: false,
          syncCustomerFeedback: true, // Enable customer feedback for messaging
        );
      case 'reviews':
        return IntegrationSettings(
          autoSync: true,
          syncInterval: 60,
          syncInventory: false,
          syncOrders: false,
          syncProducts: false,
          // Review settings (on for review platforms)
          syncReviews: true,
          syncRatings: true,
          autoRespondReviews: false,
          notifyNewReviews: true,
          syncCustomerFeedback: true,
        );
      default:
        // Fallback to ecommerce defaults
        return IntegrationSettings(
          autoSync: false,
          syncInterval: 30,
          syncInventory: true,
          syncOrders: true,
          syncProducts: true,
          // Review settings (default off)
          syncReviews: false,
          syncRatings: false,
          autoRespondReviews: false,
          notifyNewReviews: false,
          syncCustomerFeedback: false,
        );
    }
  }

  /// Encrypt credentials using SHA-256
  String _encryptCredential(String credential) {
    try {
      final bytes = utf8.encode(credential + _encryptionKey);
      final digest = sha256.convert(bytes);
      return digest.toString();
    } catch (e) {
      throw IntegrationException(
          'Failed to encrypt credential', 'ENCRYPTION_ERROR');
    }
  }

  /// Validates business ID is not empty
  void _validateBusinessId() {
    print('🔍 DEBUG: Validating business ID: "$_businessId"');
    if (_businessId.isEmpty) {
      print('❌ DEBUG: Business ID validation failed - empty business ID');
      throw IntegrationException(
          'Business ID is required for integration operations',
          'INVALID_BUSINESS_ID');
    }
    print('✅ DEBUG: Business ID validation passed');
  }

  Future<List<Integration>> fetchIntegrations() async {
    debugPrint('[IntegrationService] === fetchIntegrations START ===');
    _validateBusinessId();
    debugPrint(
        '[IntegrationService] fetchIntegrations called for businessId=$_businessId');
    try {
      final query = CollectionReferences.integrationsForBusiness(_businessId)
          .where('status', isNotEqualTo: 'deleted')
          .orderBy('createdAt', descending: true);
      debugPrint('[IntegrationService] Firestore query built successfully');
      debugPrint('[IntegrationService] About to execute query...');
      final snapshot = await query.get();
      debugPrint(
          '[IntegrationService] Query returned ${snapshot.docs.length} docs');
      debugPrint(
          '[IntegrationService] Query metadata: pending=${snapshot.metadata.hasPendingWrites}, fromCache=${snapshot.metadata.isFromCache}');

      final integrations = <Integration>[];
      for (int i = 0; i < snapshot.docs.length; i++) {
        final doc = snapshot.docs[i];
        debugPrint(
            '[IntegrationService] Processing doc ${i + 1}/${snapshot.docs.length}: ${doc.id}');
        try {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          debugPrint(
              '[IntegrationService] Integration doc: id=${doc.id}, data=$data');
          final integration = Integration.fromMap(data);
          integrations.add(integration);
          debugPrint(
              '[IntegrationService] Successfully created Integration object for ${doc.id}');
        } catch (e, stackTrace) {
          debugPrint('[IntegrationService] ERROR processing doc ${doc.id}: $e');
          debugPrint('[IntegrationService] Stack trace: $stackTrace');
          // Continue processing other docs
        }
      }

      debugPrint(
          '[IntegrationService] Returning ${integrations.length} integrations');
      debugPrint('[IntegrationService] === fetchIntegrations END ===');
      return integrations;
    } on FirebaseException catch (e) {
      debugPrint('[IntegrationService] FirebaseException: ${e.message}');
      debugPrint('[IntegrationService] FirebaseException code: ${e.code}');
      throw IntegrationException(
          'Failed to fetch integrations: ${e.message}', 'FIRESTORE_ERROR');
    } catch (e, stackTrace) {
      debugPrint('[IntegrationService] Unexpected error: $e');
      debugPrint('[IntegrationService] Stack trace: $stackTrace');
      throw IntegrationException(
          'Unexpected error while fetching integrations', 'UNKNOWN_ERROR');
    }
  }

  /// Create Instagram integration after successful OAuth
  Future<Integration> createInstagramIntegration({
    required String accessToken,
    required String userId,
    required Map<String, dynamic> profileData,
    int? expiresIn,
  }) async {
    print('🏭 DEBUG: createInstagramIntegration called with:');
    print('   - userId: $userId');
    print('   - profileData keys: ${profileData.keys.toList()}');
    print('   - expiresIn: $expiresIn');
    print('   - businessId: $_businessId');

    _validateBusinessId();
    print('✅ DEBUG: Business ID validation passed');

    try {
      final integrationData = {
        'platformId': 'instagram',
        'platformName': 'Instagram Business',
        'platformIcon': 'instagram',
        'status': 'connected',
        'createdAt': FieldValue.serverTimestamp(),
        'settings': _createDefaultSettings('social').toMap(),
        'credentials': {
          'access_token': _encryptCredential(accessToken),
          'user_id': userId,
          'expires_in': expiresIn,
          'created_at': DateTime.now().toIso8601String(),
        },
        'profile': profileData,
        'businessId': _businessId,
        'lastSyncAt': null,
        'syncStatus': 'pending',
      };

      print('📦 DEBUG: Integration data prepared, adding to Firestore...');
      final docRef =
          await CollectionReferences.integrations.add(integrationData);

      print('✅ DEBUG: Document added with ID: ${docRef.id}');

      // Fetch the created integration
      final doc = await docRef.get();
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;

      final integration = Integration.fromMap(data);
      print('🎉 DEBUG: Integration created successfully: ${integration.id}');

      return integration;
    } on FirebaseException catch (e) {
      print(
          '❌ DEBUG: FirebaseException in createInstagramIntegration: ${e.message}');
      throw IntegrationException(
          'Failed to create Instagram integration: ${e.message}',
          'FIRESTORE_ERROR');
    } catch (e) {
      print('❌ DEBUG: Unexpected error in createInstagramIntegration: $e');
      throw IntegrationException(
          'Unexpected error while creating Instagram integration',
          'UNKNOWN_ERROR');
    }
  }

  /// Create WhatsApp Business integration
  Future<Integration> createWhatsAppIntegration({
    required String phoneNumberId,
    required String accessToken,
    required String businessAccountId,
    required String verifyToken,
    required Map<String, dynamic> businessProfile,
  }) async {
    print('🏭 DEBUG: createWhatsAppIntegration called with:');
    print('   - phoneNumberId: $phoneNumberId');
    print('   - businessAccountId: $businessAccountId');
    print('   - businessProfile keys: ${businessProfile.keys.toList()}');
    print('   - businessId: $_businessId');

    _validateBusinessId();
    print('✅ DEBUG: Business ID validation passed');

    try {
      final integrationData = {
        'platformId': 'whatsapp',
        'platformName': 'WhatsApp Business',
        'platformIcon': 'whatsapp',
        'status': 'connected',
        'createdAt': FieldValue.serverTimestamp(),
        'settings': _createDefaultSettings('messaging').toMap(),
        'credentials': {
          'phone_number_id': phoneNumberId,
          'access_token': _encryptCredential(accessToken),
          'business_account_id': businessAccountId,
          'verify_token': _encryptCredential(verifyToken),
          'created_at': DateTime.now().toIso8601String(),
        },
        'profile': businessProfile,
        'businessId': _businessId,
        'lastSyncAt': null,
        'syncStatus': 'pending',
      };

      print(
          '📦 DEBUG: WhatsApp integration data prepared, adding to Firestore...');
      final docRef =
          await CollectionReferences.integrations.add(integrationData);

      print('✅ DEBUG: Document added with ID: ${docRef.id}');

      // Fetch the created integration
      final doc = await docRef.get();
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;

      final integration = Integration.fromMap(data);
      print(
          '🎉 DEBUG: WhatsApp integration created successfully: ${integration.id}');

      return integration;
    } on FirebaseException catch (e) {
      print(
          '❌ DEBUG: FirebaseException in createWhatsAppIntegration: ${e.message}');
      throw IntegrationException(
          'Failed to create WhatsApp integration: ${e.message}',
          'FIRESTORE_ERROR');
    } catch (e) {
      print('❌ DEBUG: Unexpected error in createWhatsAppIntegration: $e');
      throw IntegrationException(
          'Unexpected error while creating WhatsApp integration',
          'UNKNOWN_ERROR');
    }
  }

  /// Create Facebook Page integration
  Future<Integration> createFacebookIntegration({
    required String pageId,
    required String pageAccessToken,
    required String accessToken,
    required String userId,
    required Map<String, dynamic> pageData,
  }) async {
    print('🏭 DEBUG: createFacebookIntegration called with:');
    print('   - pageId: $pageId');
    print('   - userId: $userId');
    print('   - pageData keys: ${pageData.keys.toList()}');
    print('   - businessId: $_businessId');

    _validateBusinessId();
    print('✅ DEBUG: Business ID validation passed');

    try {
      final integrationData = {
        'platformId': 'facebook',
        'platformName': 'Facebook Page',
        'platformIcon': 'facebook',
        'status': 'connected',
        'createdAt': FieldValue.serverTimestamp(),
        'settings': _createDefaultSettings('social').toMap(),
        'credentials': {
          'page_id': pageId,
          'page_access_token': _encryptCredential(pageAccessToken),
          'access_token': _encryptCredential(accessToken),
          'user_id': userId,
          'created_at': DateTime.now().toIso8601String(),
        },
        'profile': pageData,
        'businessId': _businessId,
        'lastSyncAt': null,
        'syncStatus': 'pending',
      };

      print(
          '📦 DEBUG: Facebook integration data prepared, adding to Firestore...');
      final docRef =
          await CollectionReferences.integrations.add(integrationData);

      print('✅ DEBUG: Document added with ID: ${docRef.id}');

      // Fetch the created integration
      final doc = await docRef.get();
      final data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id;

      final integration = Integration.fromMap(data);
      print(
          '🎉 DEBUG: Facebook integration created successfully: ${integration.id}');

      return integration;
    } on FirebaseException catch (e) {
      print(
          '❌ DEBUG: FirebaseException in createFacebookIntegration: ${e.message}');
      throw IntegrationException(
          'Failed to create Facebook integration: ${e.message}',
          'FIRESTORE_ERROR');
    } catch (e) {
      print('❌ DEBUG: Unexpected error in createFacebookIntegration: $e');
      throw IntegrationException(
          'Unexpected error while creating Facebook integration',
          'UNKNOWN_ERROR');
    }
  }

  /// Sync Instagram products
  Future<Map<String, dynamic>> syncInstagramProducts(
      String integrationId) async {
    _validateBusinessId();

    try {
      final integration = await fetchIntegration(integrationId);

      if (integration.platformId != 'instagram') {
        throw IntegrationException(
            'Integration is not an Instagram integration', 'INVALID_PLATFORM');
      }

      // Here you would implement the actual sync logic
      // For now, we'll simulate the sync process
      await Future.delayed(const Duration(seconds: 2));

      // Update last sync time
      await CollectionReferences.integrations.doc(integrationId).update({
        'lastSyncAt': FieldValue.serverTimestamp(),
        'syncStatus': 'completed',
      });

      return {
        'success': true,
        'syncedProducts': 0, // This would be the actual count
        'errors': [],
        'timestamp': DateTime.now().toIso8601String(),
      };
    } on IntegrationException {
      rethrow;
    } on FirebaseException catch (e) {
      throw IntegrationException(
          'Failed to sync Instagram products: ${e.message}', 'FIRESTORE_ERROR');
    } catch (e) {
      throw IntegrationException(
          'Unexpected error during Instagram sync', 'UNKNOWN_ERROR');
    }
  }

  /// Get Instagram analytics data
  Future<Map<String, dynamic>> getInstagramAnalytics(
      String integrationId) async {
    _validateBusinessId();

    try {
      final integration = await fetchIntegration(integrationId);

      if (integration.platformId != 'instagram') {
        throw IntegrationException(
            'Integration is not an Instagram integration', 'INVALID_PLATFORM');
      }

      // Here you would call the Instagram API to get analytics
      // For now, we'll return mock data
      return {
        'followers_count': 1250,
        'following_count': 180,
        'media_count': 45,
        'engagement_rate': 3.2,
        'reach': 8500,
        'impressions': 12300,
        'profile_views': 890,
        'website_clicks': 45,
        'period': 'last_30_days',
      };
    } on IntegrationException {
      rethrow;
    } catch (e) {
      throw IntegrationException(
          'Failed to get Instagram analytics', 'UNKNOWN_ERROR');
    }
  }

  /// Get Instagram posts/media
  /// Get Instagram media via backend API
  Future<Map<String, dynamic>> getInstagramMedia(
    String integrationId, {
    int limit = 25,
    String? after,
  }) async {
    _validateBusinessId();

    try {
      // Validate parameters
      if (integrationId.isEmpty) {
        throw IntegrationException(
            'Integration ID is required', 'INVALID_INTEGRATION_ID');
      }

      // Get auth token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw IntegrationException('User not authenticated', 'AUTH_REQUIRED');
      }

      final idToken = await user.getIdToken();

      // Build API URL with query parameters
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/api/integrations/instagram/$integrationId/media');
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (after != null && after.isNotEmpty) {
        queryParams['after'] = after;
      }

      final finalUri = uri.replace(queryParameters: queryParams);

      print('🔍 DEBUG: Calling Instagram API: $finalUri');

      // Make API call
      final response = await http.get(
        finalUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          'Business-ID': _businessId,
        },
      );

      print('📊 DEBUG: API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print(
            '✅ DEBUG: Successfully fetched ${data['data']?.length ?? 0} media items');

        // Transform API response to match existing format
        return {
          'items': data['data'] ?? [],
          'nextCursor': data['paging']?['cursors']?['after'],
          'hasMore': data['paging']?['cursors']?['after'] != null,
        };
      } else if (response.statusCode == 401) {
        throw IntegrationException('Authentication failed', 'AUTH_FAILED');
      } else if (response.statusCode == 404) {
        throw IntegrationException(
            'Integration not found or inactive', 'INTEGRATION_NOT_FOUND');
      } else if (response.statusCode == 429) {
        throw IntegrationException('Rate limit exceeded', 'RATE_LIMIT');
      } else {
        final errorBody = response.body;
        print('❌ DEBUG: API Error: ${response.statusCode} - $errorBody');
        throw IntegrationException(
          'Failed to fetch Instagram media: ${response.statusCode}',
          'API_ERROR',
        );
      }
    } on IntegrationException {
      rethrow;
    } catch (e) {
      print('❌ DEBUG: Unexpected error in getInstagramMedia: $e');
      throw IntegrationException(
          'Failed to get Instagram media: $e', 'UNKNOWN_ERROR');
    }
  }

  /// Get Instagram comments for a specific post
  Future<Map<String, dynamic>> getInstagramComments(
    String integrationId,
    String postId, {
    int limit = 25,
    String? after,
  }) async {
    _validateBusinessId();

    try {
      // Validate parameters
      if (integrationId.isEmpty) {
        throw IntegrationException(
            'Integration ID is required', 'INVALID_INTEGRATION_ID');
      }
      if (postId.isEmpty) {
        throw IntegrationException('Post ID is required', 'INVALID_POST_ID');
      }

      // Get auth token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw IntegrationException('User not authenticated', 'AUTH_REQUIRED');
      }

      final idToken = await user.getIdToken();

      // Build API URL with query parameters
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/api/integrations/instagram/$integrationId/media/$postId/comments');
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      if (after != null && after.isNotEmpty) {
        queryParams['after'] = after;
      }

      final finalUri = uri.replace(queryParameters: queryParams);

      print('🔍 DEBUG: Calling Instagram Comments API: $finalUri');

      // Make API call
      final response = await http.get(
        finalUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          'Business-ID': _businessId,
        },
      );

      print('📊 DEBUG: Comments API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print(
            '✅ DEBUG: Successfully fetched ${data['data']?.length ?? 0} comments');

        // Transform API response to match expected format
        return {
          'comments': data['data'] ?? [],
          'nextCursor': data['paging']?['cursors']?['after'],
          'hasMore': data['paging']?['cursors']?['after'] != null,
        };
      } else if (response.statusCode == 401) {
        throw IntegrationException('Authentication failed', 'AUTH_FAILED');
      } else if (response.statusCode == 404) {
        throw IntegrationException(
            'Post not found or no comments available', 'POST_NOT_FOUND');
      } else if (response.statusCode == 429) {
        throw IntegrationException('Rate limit exceeded', 'RATE_LIMIT');
      } else {
        final errorBody = response.body;
        print(
            '❌ DEBUG: Comments API Error: ${response.statusCode} - $errorBody');
        throw IntegrationException(
          'Failed to fetch Instagram comments: ${response.statusCode}',
          'API_ERROR',
        );
      }
    } on IntegrationException {
      rethrow;
    } catch (e) {
      print('❌ DEBUG: Unexpected error in getInstagramComments: $e');
      throw IntegrationException(
          'Failed to get Instagram comments: $e', 'UNKNOWN_ERROR');
    }
  }

  /// Reply to an Instagram comment
  Future<Map<String, dynamic>> replyToInstagramComment(
    String integrationId,
    String postId,
    String commentId,
    String message,
  ) async {
    _validateBusinessId();

    try {
      // Validate parameters
      if (integrationId.isEmpty) {
        throw IntegrationException(
            'Integration ID is required', 'INVALID_INTEGRATION_ID');
      }
      if (postId.isEmpty) {
        throw IntegrationException('Post ID is required', 'INVALID_POST_ID');
      }
      if (commentId.isEmpty) {
        throw IntegrationException(
            'Comment ID is required', 'INVALID_COMMENT_ID');
      }
      if (message.trim().isEmpty) {
        throw IntegrationException(
            'Reply message is required', 'INVALID_MESSAGE');
      }
      if (message.length > 1000) {
        throw IntegrationException(
            'Reply message cannot exceed 1000 characters', 'MESSAGE_TOO_LONG');
      }

      // Get auth token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw IntegrationException('User not authenticated', 'AUTH_REQUIRED');
      }

      final idToken = await user.getIdToken();

      // Build API URL
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/api/integrations/instagram/$integrationId/media/$postId/comments/$commentId/replies');

      print('🔍 DEBUG: Replying to comment: $uri');

      // Make API call
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          'Business-ID': _businessId,
        },
        body: json.encode({'message': message.trim()}),
      );

      print('📊 DEBUG: Reply API Response status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('✅ DEBUG: Successfully posted reply with ID: ${data['id']}');
        return data;
      } else if (response.statusCode == 401) {
        throw IntegrationException('Authentication failed', 'AUTH_FAILED');
      } else if (response.statusCode == 404) {
        throw IntegrationException(
            'Comment not found or cannot be replied to', 'COMMENT_NOT_FOUND');
      } else if (response.statusCode == 429) {
        throw IntegrationException('Rate limit exceeded', 'RATE_LIMIT');
      } else {
        final errorBody = response.body;
        print('❌ DEBUG: Reply API Error: ${response.statusCode} - $errorBody');
        throw IntegrationException(
          'Failed to reply to comment: ${response.statusCode}',
          'API_ERROR',
        );
      }
    } on IntegrationException {
      rethrow;
    } catch (e) {
      print('❌ DEBUG: Unexpected error in replyToInstagramComment: $e');
      throw IntegrationException(
          'Failed to reply to comment: $e', 'UNKNOWN_ERROR');
    }
  }

  /// Create a new Instagram post
  Future<Map<String, dynamic>> createInstagramPost(
    String integrationId, {
    String? imageUrl,
    String? videoUrl,
    String? caption,
    String? mediaType,
    List<Map<String, String>>? children,
  }) async {
    _validateBusinessId();

    try {
      // Validate parameters
      if (integrationId.isEmpty) {
        throw IntegrationException(
            'Integration ID is required', 'INVALID_INTEGRATION_ID');
      }
      if (imageUrl == null &&
          videoUrl == null &&
          (children == null || children.isEmpty)) {
        throw IntegrationException(
            'Either image URL, video URL, or children must be provided',
            'INVALID_MEDIA');
      }
      if (caption != null && caption.length > 2200) {
        throw IntegrationException(
            'Caption cannot exceed 2200 characters', 'CAPTION_TOO_LONG');
      }

      // Get auth token
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw IntegrationException('User not authenticated', 'AUTH_REQUIRED');
      }

      final idToken = await user.getIdToken();

      // Build API URL
      final uri = Uri.parse(
          '${ApiConfig.baseUrl}/api/integrations/instagram/$integrationId/media');

      // Build request body
      final body = <String, dynamic>{};
      if (imageUrl != null) body['image_url'] = imageUrl;
      if (videoUrl != null) body['video_url'] = videoUrl;
      if (caption != null) body['caption'] = caption;
      if (mediaType != null) body['media_type'] = mediaType;
      if (children != null) body['children'] = children;

      print('🔍 DEBUG: Creating Instagram post: $uri');

      // Make API call
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          'Business-ID': _businessId,
        },
        body: json.encode(body),
      );

      print(
          '📊 DEBUG: Create Post API Response status: ${response.statusCode}');

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        print('✅ DEBUG: Successfully created post with ID: ${data['id']}');
        return data;
      } else if (response.statusCode == 401) {
        throw IntegrationException('Authentication failed', 'AUTH_FAILED');
      } else if (response.statusCode == 400) {
        throw IntegrationException(
            'Invalid post data or media', 'INVALID_POST_DATA');
      } else if (response.statusCode == 429) {
        throw IntegrationException('Rate limit exceeded', 'RATE_LIMIT');
      } else {
        final errorBody = response.body;
        print(
            '❌ DEBUG: Create Post API Error: ${response.statusCode} - $errorBody');
        throw IntegrationException(
          'Failed to create Instagram post: ${response.statusCode}',
          'API_ERROR',
        );
      }
    } on IntegrationException {
      rethrow;
    } catch (e) {
      print('❌ DEBUG: Unexpected error in createInstagramPost: $e');
      throw IntegrationException(
          'Failed to create Instagram post: $e', 'UNKNOWN_ERROR');
    }
  }

  Future<Integration> fetchIntegration(String integrationId) async {
    _validateBusinessId();

    if (integrationId.isEmpty) {
      throw IntegrationException(
          'Integration ID is required', 'INVALID_INTEGRATION_ID');
    }

    try {
      final doc =
          await CollectionReferences.integrations.doc(integrationId).get();

      if (!doc.exists) {
        throw IntegrationException(
            'Integration not found', 'INTEGRATION_NOT_FOUND');
      }

      final data = doc.data() as Map<String, dynamic>?;
      if (data?['status'] == 'deleted') {
        throw IntegrationException(
            'Integration has been deleted', 'INTEGRATION_DELETED');
      }

      // Verify integration belongs to the business
      if (data?['businessId'] != _businessId) {
        throw IntegrationException(
            'Integration not found', 'INTEGRATION_NOT_FOUND');
      }

      data!['id'] = doc.id;
      return Integration.fromMap(data);
    } on FirebaseException catch (e) {
      throw IntegrationException(
          'Failed to fetch integration: ${e.message}', 'FIRESTORE_ERROR');
    } on IntegrationException {
      rethrow;
    } catch (e) {
      throw IntegrationException(
          'Unexpected error while fetching integration', 'UNKNOWN_ERROR');
    }
  }

  Future<Integration> connectPlatform({
    required String platformId,
    required Map<String, String> credentials,
  }) async {
    _validateBusinessId();

    if (platformId.isEmpty) {
      throw IntegrationException(
          'Platform ID is required', 'INVALID_PLATFORM_ID');
    }

    if (credentials.isEmpty) {
      throw IntegrationException(
          'Credentials are required', 'MISSING_CREDENTIALS');
    }

    try {
      // Check if integration already exists for this platform
      final existingQuery = await CollectionReferences.integrationsForPlatform(
              _businessId, platformId)
          .where('status', isNotEqualTo: 'deleted')
          .get();

      if (existingQuery.docs.isNotEmpty) {
        throw IntegrationException(
            'Integration already exists for this platform',
            'DUPLICATE_INTEGRATION');
      }

      // Validate credentials with platform
      final isValid = await _validateCredentials(platformId, credentials);
      if (!isValid) {
        throw IntegrationException(
            'Invalid credentials provided', 'INVALID_CREDENTIALS');
      }

      // Get platform details
      final platform = await _getPlatformDetails(platformId);

      // Create integration document
      final docRef = CollectionReferences.integrations.doc();

      // Create platform-specific default settings
      final settings = _createDefaultSettings(platform['category'] as String);

      final integration = Integration(
        id: docRef.id,
        platformId: platformId,
        platformName: platform['name'],
        platformIcon: platform['icon'],
        channel: _getChannelFromPlatform(platform['name']),
        status: 'connected',
        createdAt: DateTime.now(),
        settings: settings,
      );

      // Encrypt sensitive credentials
      final encryptedCredentials = credentials.map(
        (key, value) => MapEntry(key, _encryptCredential(value)),
      );

      await docRef.set({
        ...integration.toMap(),
        'businessId': _businessId, // Add businessId for flat structure
        'credentials': encryptedCredentials,
        'createdBy': _businessId,
        'lastSyncAt': null,
        'syncCount': 0,
      });

      return integration;
    } on FirebaseException catch (e) {
      throw IntegrationException(
          'Failed to connect platform: ${e.message}', 'FIRESTORE_ERROR');
    } on IntegrationException {
      rethrow;
    } catch (e) {
      throw IntegrationException(
          'Unexpected error while connecting platform', 'UNKNOWN_ERROR');
    }
  }

  Future<void> disconnectIntegration(String integrationId) async {
    _validateBusinessId();

    if (integrationId.isEmpty) {
      throw IntegrationException(
          'Integration ID is required', 'INVALID_INTEGRATION_ID');
    }

    try {
      // Check if integration exists
      final doc =
          await CollectionReferences.integrations.doc(integrationId).get();

      if (!doc.exists) {
        throw IntegrationException(
            'Integration not found', 'INTEGRATION_NOT_FOUND');
      }

      final data = doc.data() as Map<String, dynamic>?;

      // Verify integration belongs to the business
      if (data?['businessId'] != _businessId) {
        throw IntegrationException(
            'Integration not found', 'INTEGRATION_NOT_FOUND');
      }

      if (data?['status'] == 'disconnected') {
        throw IntegrationException(
            'Integration is already disconnected', 'ALREADY_DISCONNECTED');
      }

      await CollectionReferences.integrations.doc(integrationId).update({
        'status': 'disconnected',
        'disconnectedAt': FieldValue.serverTimestamp(),
        'disconnectedBy': _businessId,
      });
    } on FirebaseException catch (e) {
      throw IntegrationException(
          'Failed to disconnect integration: ${e.message}', 'FIRESTORE_ERROR');
    } on IntegrationException {
      rethrow;
    } catch (e) {
      throw IntegrationException(
          'Unexpected error while disconnecting integration', 'UNKNOWN_ERROR');
    }
  }

  Future<void> updateIntegrationSettings({
    required String integrationId,
    required IntegrationSettings settings,
  }) async {
    _validateBusinessId();

    if (integrationId.isEmpty) {
      throw IntegrationException(
          'Integration ID is required', 'INVALID_INTEGRATION_ID');
    }

    try {
      // Check if integration exists and is active
      final doc =
          await CollectionReferences.integrations.doc(integrationId).get();

      if (!doc.exists) {
        throw IntegrationException(
            'Integration not found', 'INTEGRATION_NOT_FOUND');
      }

      final data = doc.data() as Map<String, dynamic>?;

      // Verify integration belongs to the business
      if (data?['businessId'] != _businessId) {
        throw IntegrationException(
            'Integration not found', 'INTEGRATION_NOT_FOUND');
      }

      final status = data?['status'];
      if (status == 'disconnected' || status == 'deleted') {
        throw IntegrationException(
            'Cannot update settings for inactive integration',
            'INTEGRATION_INACTIVE');
      }

      // Validate sync interval
      if (settings.autoSync && settings.syncInterval < 5) {
        throw IntegrationException('Sync interval must be at least 5 minutes',
            'INVALID_SYNC_INTERVAL');
      }

      await CollectionReferences.integrations.doc(integrationId).update({
        'settings': settings.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': _businessId,
      });
    } on FirebaseException catch (e) {
      throw IntegrationException(
          'Failed to update integration settings: ${e.message}',
          'FIRESTORE_ERROR');
    } on IntegrationException {
      rethrow;
    } catch (e) {
      throw IntegrationException(
          'Unexpected error while updating settings', 'UNKNOWN_ERROR');
    }
  }

  /// Triggers manual sync for an integration
  Future<void> syncIntegration(String integrationId) async {
    _validateBusinessId();

    if (integrationId.isEmpty) {
      throw IntegrationException(
          'Integration ID is required', 'INVALID_INTEGRATION_ID');
    }

    try {
      final integration = await fetchIntegration(integrationId);

      if (integration.status != 'connected') {
        throw IntegrationException('Can only sync connected integrations',
            'INTEGRATION_NOT_CONNECTED');
      }

      // Update last sync timestamp and increment sync count
      await CollectionReferences.integrations.doc(integrationId).update({
        'lastSyncAt': FieldValue.serverTimestamp(),
        'syncCount': FieldValue.increment(1),
        'lastSyncStatus': 'success',
      });

      // TODO: Implement actual platform synchronization logic
      // This would involve calling the respective platform APIs
    } on FirebaseException catch (e) {
      throw IntegrationException(
          'Failed to sync integration: ${e.message}', 'FIRESTORE_ERROR');
    } on IntegrationException {
      rethrow;
    } catch (e) {
      throw IntegrationException(
          'Unexpected error during sync', 'UNKNOWN_ERROR');
    }
  }

  /// Soft delete an integration (marks as deleted instead of removing)
  Future<void> deleteIntegration(String integrationId) async {
    _validateBusinessId();

    if (integrationId.isEmpty) {
      throw IntegrationException(
          'Integration ID is required', 'INVALID_INTEGRATION_ID');
    }

    try {
      final doc =
          await CollectionReferences.integrations.doc(integrationId).get();

      if (!doc.exists) {
        throw IntegrationException(
            'Integration not found', 'INTEGRATION_NOT_FOUND');
      }

      final data = doc.data() as Map<String, dynamic>?;

      // Verify integration belongs to the business
      if (data?['businessId'] != _businessId) {
        throw IntegrationException(
            'Integration not found', 'INTEGRATION_NOT_FOUND');
      }

      await CollectionReferences.integrations.doc(integrationId).update({
        'status': 'deleted',
        'deletedAt': FieldValue.serverTimestamp(),
        'deletedBy': _businessId,
      });
    } on FirebaseException catch (e) {
      throw IntegrationException(
          'Failed to delete integration: ${e.message}', 'FIRESTORE_ERROR');
    } on IntegrationException {
      rethrow;
    } catch (e) {
      throw IntegrationException(
          'Unexpected error while deleting integration', 'UNKNOWN_ERROR');
    }
  }

  Future<bool> _validateCredentials(
      String platformId, Map<String, String> credentials) async {
    switch (platformId) {
      // E-commerce Platforms
      case 'shopify':
        return credentials.containsKey('apiKey') &&
            credentials.containsKey('apiSecret');
      case 'woocommerce':
        return credentials.containsKey('consumerKey') &&
            credentials.containsKey('consumerSecret');
      case 'amazon':
        return credentials.containsKey('accessKey') &&
            credentials.containsKey('secretKey');
      case 'ebay':
        return credentials.containsKey('appId') &&
            credentials.containsKey('certId');
      case 'magento':
        return credentials.containsKey('accessToken') &&
            credentials.containsKey('storeUrl');

      // Payment Platforms
      case 'stripe':
        return credentials.containsKey('publishableKey') &&
            credentials.containsKey('secretKey');
      case 'paypal':
        return credentials.containsKey('clientId') &&
            credentials.containsKey('clientSecret');
      case 'square':
        return credentials.containsKey('applicationId') &&
            credentials.containsKey('accessToken');
      case 'razorpay':
        return credentials.containsKey('keyId') &&
            credentials.containsKey('keySecret');
      case 'paystack':
        return credentials.containsKey('publicKey') &&
            credentials.containsKey('secretKey');
      case 'flutterwave':
        return credentials.containsKey('publicKey') &&
            credentials.containsKey('secretKey');

      // Social Media Platforms
      case 'facebook':
        return credentials.containsKey('appId') &&
            credentials.containsKey('appSecret') &&
            credentials.containsKey('accessToken');
      case 'instagram':
        return credentials.containsKey('appId') &&
            credentials.containsKey('appSecret') &&
            credentials.containsKey('accessToken');
      case 'twitter':
        return credentials.containsKey('consumerKey') &&
            credentials.containsKey('consumerSecret') &&
            credentials.containsKey('accessToken') &&
            credentials.containsKey('accessTokenSecret');
      case 'tiktok':
        return credentials.containsKey('appId') &&
            credentials.containsKey('appSecret') &&
            credentials.containsKey('accessToken');
      case 'whatsapp_business':
        return credentials.containsKey('phoneNumberId') &&
            credentials.containsKey('accessToken');
      case 'telegram':
        return credentials.containsKey('botToken') &&
            credentials.containsKey('chatId');

      // Review & Feedback Platforms
      case 'google_business':
        return credentials.containsKey('placeId') &&
            credentials.containsKey('apiKey');
      case 'google_reviews':
        return credentials.containsKey('businessId') &&
            credentials.containsKey('serviceAccountKey');
      case 'trustpilot':
        return credentials.containsKey('apiKey') &&
            credentials.containsKey('businessUnitId');
      case 'yelp':
        return credentials.containsKey('apiKey') &&
            credentials.containsKey('businessId');
      case 'tripadvisor':
        return credentials.containsKey('apiKey') &&
            credentials.containsKey('locationId');
      case 'bazaarvoice':
        return credentials.containsKey('apiKey') &&
            credentials.containsKey('clientId');
      case 'yotpo':
        return credentials.containsKey('appKey') &&
            credentials.containsKey('secret');
      case 'reviews_io':
        return credentials.containsKey('apiKey') &&
            credentials.containsKey('storeId');
      case 'shopify_reviews':
        return credentials.containsKey('shopDomain') &&
            credentials.containsKey('accessToken');
      case 'woocommerce_reviews':
        return credentials.containsKey('consumerKey') &&
            credentials.containsKey('consumerSecret') &&
            credentials.containsKey('storeUrl');

      default:
        return credentials.isNotEmpty;
    }
  }

  /// Get all supported platforms for online stores
  Future<List<Map<String, dynamic>>> getSupportedPlatforms() async {
    // Return e-commerce and marketplace platforms for online stores
    final platformIds = [
      'shopify',
      'woocommerce',
      'magento',
      'amazon',
      'ebay',
    ];

    final platforms = <Map<String, dynamic>>[];
    for (final platformId in platformIds) {
      final platformDetails = await _getPlatformDetails(platformId);
      platforms.add({
        'id': platformId,
        'name': platformDetails['name'],
        'icon': platformDetails['icon'],
        'category': platformDetails['category'],
      });
    }

    return platforms;
  }

  /// Check if user has an existing integration for the specified platform
  Future<bool> hasIntegrationForPlatform(String platformId) async {
    try {
      final integrations = await fetchIntegrations();
      return integrations
          .any((integration) => integration.platformId == platformId);
    } catch (e) {
      // If there's an error fetching integrations, assume no integration exists
      return false;
    }
  }

  Future<Map<String, dynamic>> _getPlatformDetails(String platformId) async {
    switch (platformId) {
      // E-commerce Platforms
      case 'shopify':
        return {
          'name': 'Shopify',
          'icon': 'assets/icons/shopify.png',
          'category': 'ecommerce',
        };
      case 'woocommerce':
        return {
          'name': 'WooCommerce',
          'icon': 'assets/icons/woocommerce.png',
          'category': 'ecommerce',
        };
      case 'magento':
        return {
          'name': 'Magento',
          'icon': 'assets/icons/magento.png',
          'category': 'ecommerce',
        };
      case 'amazon':
        return {
          'name': 'Amazon',
          'icon': 'assets/icons/amazon.png',
          'category': 'marketplace',
        };
      case 'ebay':
        return {
          'name': 'eBay',
          'icon': 'assets/icons/ebay.png',
          'category': 'marketplace',
        };

      // Payment Platforms
      case 'stripe':
        return {
          'name': 'Stripe',
          'icon': 'assets/icons/stripe.png',
          'category': 'payment',
        };
      case 'paypal':
        return {
          'name': 'PayPal',
          'icon': 'assets/icons/paypal.png',
          'category': 'payment',
        };
      case 'square':
        return {
          'name': 'Square',
          'icon': 'assets/icons/square.png',
          'category': 'payment',
        };
      case 'razorpay':
        return {
          'name': 'Razorpay',
          'icon': 'assets/icons/razorpay.png',
          'category': 'payment',
        };
      case 'paystack':
        return {
          'name': 'Paystack',
          'icon': 'assets/icons/paystack.png',
          'category': 'payment',
        };
      case 'flutterwave':
        return {
          'name': 'Flutterwave',
          'icon': 'assets/icons/flutterwave.png',
          'category': 'payment',
        };

      // Social Media Platforms
      case 'facebook':
        return {
          'name': 'Facebook',
          'icon': 'assets/icons/facebook.png',
          'category': 'social',
        };
      case 'instagram':
        return {
          'name': 'Instagram',
          'icon': 'assets/icons/instagram.png',
          'category': 'social',
        };
      case 'twitter':
        return {
          'name': 'Twitter',
          'icon': 'assets/icons/twitter.png',
          'category': 'social',
        };
      case 'tiktok':
        return {
          'name': 'TikTok',
          'icon': 'assets/icons/tiktok.png',
          'category': 'social',
        };
      case 'whatsapp_business':
        return {
          'name': 'WhatsApp Business',
          'icon': 'assets/icons/whatsapp.png',
          'category': 'social',
        };
      case 'telegram':
        return {
          'name': 'Telegram',
          'icon': 'assets/icons/telegram.png',
          'category': 'social',
        };

      // Review & Feedback Platforms
      case 'google_business':
        return {
          'name': 'Google My Business',
          'icon': 'assets/icons/google_business.png',
          'category': 'reviews',
        };
      case 'google_reviews':
        return {
          'name': 'Google Reviews',
          'icon': 'assets/icons/google_reviews.png',
          'category': 'reviews',
        };
      case 'trustpilot':
        return {
          'name': 'Trustpilot',
          'icon': 'assets/icons/trustpilot.png',
          'category': 'reviews',
        };
      case 'yelp':
        return {
          'name': 'Yelp',
          'icon': 'assets/icons/yelp.png',
          'category': 'reviews',
        };
      case 'tripadvisor':
        return {
          'name': 'TripAdvisor',
          'icon': 'assets/icons/tripadvisor.png',
          'category': 'reviews',
        };
      case 'bazaarvoice':
        return {
          'name': 'Bazaarvoice',
          'icon': 'assets/icons/bazaarvoice.png',
          'category': 'reviews',
        };
      case 'yotpo':
        return {
          'name': 'Yotpo',
          'icon': 'assets/icons/yotpo.png',
          'category': 'reviews',
        };
      case 'reviews_io':
        return {
          'name': 'Reviews.io',
          'icon': 'assets/icons/reviews_io.png',
          'category': 'reviews',
        };
      case 'shopify_reviews':
        return {
          'name': 'Shopify Reviews',
          'icon': 'assets/icons/shopify_reviews.png',
          'category': 'reviews',
        };
      case 'woocommerce_reviews':
        return {
          'name': 'WooCommerce Reviews',
          'icon': 'assets/icons/woocommerce_reviews.png',
          'category': 'reviews',
        };

      default:
        return {
          'name': 'Custom Platform',
          'icon': 'assets/icons/platform.png',
          'category': 'other',
        };
    }
  }

  /// Get channel name from platform name
  String _getChannelFromPlatform(String platformName) {
    switch (platformName.toLowerCase()) {
      case 'instagram business':
      case 'instagram':
        return 'instagram';
      case 'facebook pages':
      case 'facebook':
        return 'facebook';
      case 'messenger':
        return 'messenger';
      case 'whatsapp business':
      case 'whatsapp':
        return 'whatsapp';
      case 'tiktok business':
      case 'tiktok':
        return 'tiktok';
      default:
        return platformName.toLowerCase().replaceAll(' ', '_');
    }
  }

  /// Get Messenger analytics for a specific integration
  Future<Map<String, dynamic>> getMessengerAnalytics(
      String integrationId) async {
    try {
      final idToken = await getUserIdToken();
      debugPrint('call url ${ApiConfig.getMessengerAnalytics(integrationId)}');

      final response = await http.get(
        Uri.parse(ApiConfig.getMessengerAnalytics(integrationId)),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          'Business-ID': _businessId,
        },
      );
      debugPrint('Fetching Messenger analytics for integration $integrationId');
      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Raw response body: ${response.body}');

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw IntegrationException('Authentication failed', 'AUTH_FAILED');
      } else if (response.statusCode == 404) {
        throw IntegrationException(
            'No Messenger integration found', 'INTEGRATION_NOT_FOUND');
      } else {
        final errorBody = json.decode(response.body);
        throw IntegrationException(
          errorBody['message'] ?? 'Failed to fetch Messenger analytics',
          'API_ERROR',
        );
      }
    } catch (e) {
      if (e is IntegrationException) {
        rethrow;
      }
      if (kDebugMode) {
        print('❌ DEBUG: Error fetching Messenger analytics: $e');
      }
      throw IntegrationException(
        'Failed to fetch Messenger analytics: ${e.toString()}',
        'NETWORK_ERROR',
      );
    }
  }

  /// Get Messenger conversations for a specific integration
  Future<Map<String, dynamic>> getMessengerConversations(String integrationId,
      {int limit = 25}) async {
    try {
      final idToken = await getUserIdToken();

      final uri = Uri.parse(ApiConfig.getMessengerConversations(integrationId));
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };

      final finalUri = uri.replace(queryParameters: queryParams);

      final response = await http.get(
        finalUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
          'Business-ID': _businessId,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw IntegrationException('Authentication failed', 'AUTH_FAILED');
      } else if (response.statusCode == 404) {
        throw IntegrationException(
            'No Messenger integration found', 'INTEGRATION_NOT_FOUND');
      } else {
        final errorBody = json.decode(response.body);
        throw IntegrationException(
          errorBody['message'] ?? 'Failed to fetch Messenger conversations',
          'API_ERROR',
        );
      }
    } catch (e) {
      if (e is IntegrationException) {
        rethrow;
      }
      if (kDebugMode) {
        print('❌ DEBUG: Error fetching Messenger conversations: $e');
      }
      throw IntegrationException(
        'Failed to fetch Messenger conversations: ${e.toString()}',
        'NETWORK_ERROR',
      );
    }
  }
}
