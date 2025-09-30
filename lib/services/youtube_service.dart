import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:vendor_app/models/youtube_models.dart';
import 'package:vendor_app/config/api_config.dart';

class YouTubeService {
  /// Get YouTube integration status for a business
  static Future<Map<String, dynamic>?> getIntegrationStatus(
      String businessId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getYouTubeIntegrationStatus()),
        headers: {
          'Business-ID': businessId,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception(
            'Failed to get integration status: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error fetching YouTube integration status: $error');
    }
  }

  /// Get YouTube authorization URL
  static Future<String> getAuthorizationUrl(String businessId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getYouTubeAuthUrl(businessId: businessId)),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final authUrl = data['auth_url'];
        if (authUrl == null) {
          throw Exception('No authorization URL received');
        }
        return authUrl;
      } else {
        throw Exception(
            'Failed to get authorization URL: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error getting YouTube authorization URL: $error');
    }
  }

  /// Get YouTube channel information
  static Future<YouTubeChannelInfo?> getChannelInfo(String businessId) async {
    try {
      final response = await http.get(
        Uri.parse(ApiConfig.getYouTubeUserInfo()),
        headers: {
          'Business-ID': businessId,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return YouTubeChannelInfo.fromJson(data);
      } else if (response.statusCode == 404) {
        return null; // No channel connected
      } else {
        throw Exception('Failed to get channel info: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error fetching YouTube channel info: $error');
    }
  }

  /// Update YouTube integration settings
  static Future<void> updateIntegrationSettings(
    String businessId,
    YouTubeIntegrationConfig config,
  ) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.getYouTubeIntegrationSettings()),
        headers: {
          'Business-ID': businessId,
          'Content-Type': 'application/json',
        },
        body: json.encode(config.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update settings: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error updating YouTube integration settings: $error');
    }
  }

  /// Disconnect YouTube integration
  static Future<void> disconnectIntegration(String businessId) async {
    try {
      final response = await http.put(
        Uri.parse(ApiConfig.getYouTubeIntegrationDisconnect()),
        headers: {
          'Business-ID': businessId,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to disconnect: ${response.statusCode}');
      }
    } catch (error) {
      throw Exception('Error disconnecting YouTube integration: $error');
    }
  }
}
