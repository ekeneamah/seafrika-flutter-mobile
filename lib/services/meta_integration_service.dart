import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class MetaIntegrationService {
  /// Generate OAuth URL for multiple Meta channels
  ///
  /// [channels] - List of channels to integrate: ['facebook_pages', 'messenger', 'instagram']
  /// [businessId] - Business ID for context
  /// [state] - Optional state parameter
  static Future<MetaOAuthUrlResponse> generateOAuthUrl({
    required List<String> channels,
    String? businessId,
    String? state,
  }) async {
    final redirectUri = ApiConfig.getFullUrl(ApiConfig.metaOAuthRedirectPath);
    final channelsParam = channels.join(',');

    final queryParams = {
      'redirect_uri': redirectUri,
      'channels': channelsParam,
      if (state != null) 'state': state,
    };

    final uri = Uri.parse(ApiConfig.getFullUrl(ApiConfig.metaAuthPath)).replace(
      queryParameters: queryParams,
    );
    print('Generating Meta OAuth URL with URI: $uri');
    print('Business ID: $businessId');
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (businessId != null) 'Business-ID': businessId,
    };

    try {
      final response = await http.get(uri, headers: headers);
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        final rawData = json.decode(response.body);

        // Handle nested response structure with "data" key
        final data = rawData['data'] ?? rawData;
        return MetaOAuthUrlResponse.fromJson(data);
      } else {
        final errorData = json.decode(response.body);
        throw MetaIntegrationException(
          'Failed to generate OAuth URL: ${errorData['message'] ?? 'Unknown error'}',
          response.statusCode,
        );
      }
    } catch (e) {
      print('Error generating Meta OAuth URL: $e');
      if (e is MetaIntegrationException) rethrow;
      throw MetaIntegrationException('Network error: $e', 0);
    }
  }

  /// Legacy method for Instagram-only OAuth (backward compatibility)
  static Future<MetaOAuthUrlResponse> generateInstagramOAuthUrl({
    String? businessId,
    String? state,
  }) async {
    return generateOAuthUrl(
      channels: ['instagram'],
      businessId: businessId,
      state: state,
    );
  }

  /// Generate OAuth URL for Facebook Pages only
  static Future<MetaOAuthUrlResponse> generateFacebookPagesOAuthUrl({
    String? businessId,
    String? state,
  }) async {
    return generateOAuthUrl(
      channels: ['facebook_pages'],
      businessId: businessId,
      state: state,
    );
  }

  /// Generate OAuth URL for Messenger only
  static Future<MetaOAuthUrlResponse> generateMessengerOAuthUrl({
    String? businessId,
    String? state,
  }) async {
    return generateOAuthUrl(
      channels: ['messenger'],
      businessId: businessId,
      state: state,
    );
  }

  /// Generate OAuth URL for all Meta platforms
  static Future<MetaOAuthUrlResponse> generateAllPlatformsOAuthUrl({
    String? businessId,
    String? state,
  }) async {
    return generateOAuthUrl(
      channels: ['facebook_pages', 'messenger', 'instagram'],
      businessId: businessId,
      state: state,
    );
  }
}

/// OAuth URL response model
class MetaOAuthUrlResponse {
  final String authUrl;
  final String redirectUri;
  final List<String> channels;
  final String? state;
  final String? businessId;
  final String appId;
  final Map<String, String> instructions;

  MetaOAuthUrlResponse({
    required this.authUrl,
    required this.redirectUri,
    required this.channels,
    this.state,
    this.businessId,
    required this.appId,
    required this.instructions,
  });

  factory MetaOAuthUrlResponse.fromJson(Map<String, dynamic> json) {
    return MetaOAuthUrlResponse(
      authUrl: json['auth_url'] as String,
      redirectUri: json['redirect_uri'] as String,
      channels: List<String>.from(json['channels'] ?? []),
      state: json['state'] as String?,
      businessId: json['business_id'] as String?,
      appId: json['app_id'] as String,
      instructions: Map<String, String>.from(json['instructions'] ?? {}),
    );
  }

  /// Get user-friendly description of channels
  String get channelDescriptions {
    final descriptions = <String>[];
    if (channels.contains('facebook_pages')) {
      descriptions.add('Facebook Pages');
    }
    if (channels.contains('messenger')) {
      descriptions.add('Messenger');
    }
    if (channels.contains('instagram')) {
      descriptions.add('Instagram Business');
    }
    return descriptions.join(', ');
  }

  @override
  String toString() {
    return 'MetaOAuthUrlResponse(authUrl: $authUrl, redirectUri: $redirectUri, appId: $appId, channels: ${channels.join(',')}, state: $state, businessId: $businessId)';
  }

  /// Get the minimum required scopes for the channels
  List<String> get requiredScopes {
    final scopes = <String>{};

    if (channels.contains('facebook_pages')) {
      scopes.addAll([
        'pages_show_list',
        'pages_manage_metadata',
        'pages_manage_posts',
        'pages_manage_engagement',
        'pages_read_engagement',
      ]);
    }

    if (channels.contains('messenger')) {
      scopes.addAll([
        'pages_show_list',
        'pages_manage_metadata',
        'pages_messaging',
      ]);
    }

    if (channels.contains('instagram')) {
      scopes.addAll([
        'instagram_basic',
        'instagram_content_publish',
        'instagram_manage_comments',
        'instagram_manage_messages',
        'pages_show_list',
        'pages_manage_metadata',
        'business_management',
      ]);
    }

    return scopes.toList();
  }
}

/// Exception for Meta integration errors
class MetaIntegrationException implements Exception {
  final String message;
  final int statusCode;

  MetaIntegrationException(this.message, this.statusCode);

  @override
  String toString() => 'MetaIntegrationException: $message (HTTP $statusCode)';
}

/// Helper class for Meta integration capabilities
class MetaIntegrationCapabilities {
  /// Get available capabilities for each channel
  static Map<String, List<String>> getChannelCapabilities() {
    return {
      'facebook_pages': [
        'Read and publish posts',
        'Manage comments',
        'Read engagement metrics',
        'Manage page metadata',
      ],
      'messenger': [
        'Send and receive messages',
        'Mark messages as seen',
        'Typing indicators',
        'Message delivery receipts',
      ],
      'instagram': [
        'Publish media content',
        'Manage comments',
        'Send and receive DMs',
        'Access business insights',
      ],
    };
  }

  /// Check if a channel requires app review for certain features
  static Map<String, List<String>> getAppReviewRequirements() {
    return {
      'facebook_pages': [
        'Publishing posts requires pages_manage_posts permission (App Review)',
        'Reading engagement requires pages_read_engagement permission',
      ],
      'messenger': [
        'Messaging requires pages_messaging permission (App Review)',
        'Advanced messaging features may require additional review',
      ],
      'instagram': [
        'Publishing requires instagram_content_publish permission (App Review)',
        'Managing comments requires instagram_manage_comments permission (App Review)',
        'DMs require instagram_manage_messages permission (App Review)',
      ],
    };
  }
}
