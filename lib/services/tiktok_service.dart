import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class TikTokService {
  final _storage = const FlutterSecureStorage();
  final http.Client _client;

  TikTokService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<String, String>> _getHeaders(String businessId,
      {String? userId, String? token}) async {
    final authToken = token ?? await _storage.read(key: 'auth_token') ?? '';
    final userIdValue = userId ?? await _storage.read(key: 'user_id') ?? '';

    return {
      'Content-Type': 'application/json',
      'Business-ID': businessId,
      'User-ID': userIdValue,
      'Authorization': 'Bearer $authToken',
    };
  }

  Future<Map<String, String>> _getMultipartHeaders(String businessId,
      {String? userId, String? token}) async {
    final authToken = token ?? await _storage.read(key: 'auth_token') ?? '';
    final userIdValue = userId ?? await _storage.read(key: 'user_id') ?? '';

    return {
      'Business-ID': businessId,
      'User-ID': userIdValue,
      'Authorization': 'Bearer $authToken',
    };
  }

  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  // Authentication Methods
  Future<Map<String, dynamic>> authenticateTikTok({
    required String code,
    required String redirectUri,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.getFullUrl('${ApiConfig.tiktokConfigBasePath}/auth')),
      headers: await _getHeaders(businessId, userId: userId, token: token),
      body: jsonEncode({
        'code': code,
        'redirectUri': redirectUri,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> disconnectTikTok({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.delete(
      Uri.parse(ApiConfig.getFullUrl('${ApiConfig.tiktokConfigBasePath}/auth')),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  // OAuth URL Generation
  Future<Map<String, dynamic>> getTikTokAuthUrl({
    required String redirectUri,
    required String businessId,
    String? state,
    String? userId,
    String? token,
  }) async {
    final queryParams = <String, String>{
      'redirect_uri': redirectUri,
    };
    if (state != null) queryParams['state'] = state;

    final uri = Uri.parse(ApiConfig.getTikTokAuthUrl()).replace(
      queryParameters: queryParams,
    );

    final response = await _client.get(
      uri,
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  // User Profile Methods
  Future<Map<String, dynamic>> getUserProfile({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.get(
      Uri.parse(ApiConfig.getTikTokUserProfile()),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getUserInfo({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.get(
      Uri.parse(ApiConfig.getTikTokUserInfo()),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  // Video Methods
  Future<Map<String, dynamic>> getUserVideos({
    required String businessId,
    int limit = 20,
    String? cursor,
    String? userId,
    String? token,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };
    if (cursor != null) queryParams['cursor'] = cursor;

    final uri = Uri.parse(ApiConfig.getTikTokVideos()).replace(
      queryParameters: queryParams,
    );

    final response = await _client.get(
      uri,
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getVideoInfo({
    required String videoId,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.get(
      Uri.parse(ApiConfig.getTikTokVideo(videoId)),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  // Comment Methods
  Future<Map<String, dynamic>> getVideoComments({
    required String videoId,
    required String businessId,
    int limit = 20,
    String? cursor,
    String? userId,
    String? token,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };
    if (cursor != null) queryParams['cursor'] = cursor;

    final uri = Uri.parse(ApiConfig.getTikTokVideoComments(videoId)).replace(
      queryParameters: queryParams,
    );

    final response = await _client.get(
      uri,
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> replyToComment({
    required String videoId,
    required String commentId,
    required String text,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.getTikTokCommentReply(videoId, commentId)),
      headers: await _getHeaders(businessId, userId: userId, token: token),
      body: jsonEncode({
        'text': text,
      }),
    );
    return _handleResponse(response);
  }

  // Analytics Methods
  Future<Map<String, dynamic>> getVideoAnalytics({
    required String videoId,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.get(
      Uri.parse(ApiConfig.getTikTokVideoAnalytics(videoId)),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getUserAnalytics({
    required String businessId,
    String? dateRange,
    String? userId,
    String? token,
  }) async {
    final queryParams = <String, String>{};
    if (dateRange != null) queryParams['date_range'] = dateRange;

    final uri = Uri.parse(ApiConfig.getTikTokUserAnalytics()).replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );

    final response = await _client.get(
      uri,
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  // Integration Management Methods
  Future<Map<String, dynamic>> getIntegrationStatus({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.get(
      Uri.parse(ApiConfig.getTikTokIntegrationStatus()),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> updateIntegrationSettings({
    required String businessId,
    required Map<String, dynamic> settings,
    String? userId,
    String? token,
  }) async {
    final response = await _client.put(
      Uri.parse(ApiConfig.getTikTokIntegrationSettings()),
      headers: await _getHeaders(businessId, userId: userId, token: token),
      body: jsonEncode(settings),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> syncTikTokData({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.getTikTokIntegrationSync()),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  // Content Management Methods
  Future<Map<String, dynamic>> uploadVideo({
    required File videoFile,
    required String title,
    String? description,
    List<String>? tags,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.getTikTokUploadVideo()),
    );

    request.headers.addAll(
        await _getMultipartHeaders(businessId, userId: userId, token: token));

    request.files
        .add(await http.MultipartFile.fromPath('video', videoFile.path));
    request.fields['title'] = title;
    if (description != null) request.fields['description'] = description;
    if (tags != null) request.fields['tags'] = jsonEncode(tags);

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> getUploadStatus({
    required String uploadId,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.get(
      Uri.parse(ApiConfig.getTikTokUploadStatus(uploadId)),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  // Webhook Management
  Future<Map<String, dynamic>> getWebhookInfo({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.get(
      Uri.parse(ApiConfig.getTikTokInfo()),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> subscribeToWebhooks({
    required String businessId,
    required List<String> events,
    String? userId,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.getTikTokSubscribe()),
      headers: await _getHeaders(businessId, userId: userId, token: token),
      body: jsonEncode({
        'events': events,
      }),
    );
    return _handleResponse(response);
  }

  // Error handling and logging
  Future<List<Map<String, dynamic>>> getIntegrationLogs({
    required String businessId,
    int limit = 50,
    String? userId,
    String? token,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
    };

    final uri = Uri.parse(ApiConfig.getTikTokIntegrationLogs()).replace(
      queryParameters: queryParams,
    );

    final response = await _client.get(
      uri,
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    final result = _handleResponse(response);
    return List<Map<String, dynamic>>.from(result['logs'] ?? []);
  }

  // Dispose method
  void dispose() {
    _client.close();
  }
}
