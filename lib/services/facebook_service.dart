import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class FacebookService {
  final _storage = const FlutterSecureStorage();
  final http.Client _client;

  FacebookService({http.Client? client}) : _client = client ?? http.Client();

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
  Future<Map<String, dynamic>> authenticateFacebook({
    required String code,
    required String redirectUri,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.getFacebookAuth()),
      headers: await _getHeaders(businessId, userId: userId, token: token),
      body: jsonEncode({
        'code': code,
        'redirectUri': redirectUri,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> disconnectFacebook({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.delete(
      Uri.parse(ApiConfig.getFacebookAuth()),
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
      Uri.parse(ApiConfig.getFacebookUserProfile()),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  Future<List<dynamic>> getUserPages({
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.get(
      Uri.parse(ApiConfig.getFacebookUserPages()),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response)['data'] ?? [];
  }

  // Page Management Methods
  Future<Map<String, dynamic>> subscribePageWebhooks({
    required String pageId,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.getFacebookPageSubscribeWebhook(pageId)),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  Future<List<dynamic>> getPageRoles({
    required String pageId,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.get(
      Uri.parse(ApiConfig.getFacebookPageRoles(pageId)),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response)['data'] ?? [];
  }

  Future<Map<String, dynamic>> getPageInsights({
    required String pageId,
    required String businessId,
    String? metric,
    String? period,
    String? userId,
    String? token,
  }) async {
    final uri = Uri.parse(ApiConfig.getFacebookPageInsights(pageId));
    final queryParams = <String, String>{};
    if (metric != null) queryParams['metric'] = metric;
    if (period != null) queryParams['period'] = period;

    final response = await _client.get(
      uri.replace(queryParameters: queryParams.isNotEmpty ? queryParams : null),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  // Content Sharing Methods
  Future<Map<String, dynamic>> shareToTimeline({
    required String message,
    required String businessId,
    String? link,
    String? imageUrl,
    String? userId,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.getFacebookShareTimeline()),
      headers: await _getHeaders(businessId, userId: userId, token: token),
      body: jsonEncode({
        'message': message,
        if (link != null) 'link': link,
        if (imageUrl != null) 'imageUrl': imageUrl,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> createPagePost({
    required String pageId,
    required String message,
    required String businessId,
    String? link,
    String? imageUrl,
    bool published = true,
    String? userId,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.getFacebookPagePosts(pageId)),
      headers: await _getHeaders(businessId, userId: userId, token: token),
      body: jsonEncode({
        'message': message,
        if (link != null) 'link': link,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'published': published,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> uploadPagePhoto({
    required String pageId,
    required File photo,
    required String businessId,
    String? caption,
    bool published = true,
    String? userId,
    String? token,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.getFacebookPagePhotos(pageId)),
    );

    request.headers.addAll(
        await _getMultipartHeaders(businessId, userId: userId, token: token));
    request.files.add(await http.MultipartFile.fromPath('photo', photo.path));

    if (caption != null) request.fields['caption'] = caption;
    request.fields['published'] = published.toString();

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> uploadPageVideo({
    required String pageId,
    required File video,
    required String businessId,
    String? title,
    String? description,
    bool published = true,
    String? userId,
    String? token,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.getFacebookPageVideos(pageId)),
    );

    request.headers.addAll(
        await _getMultipartHeaders(businessId, userId: userId, token: token));
    request.files.add(await http.MultipartFile.fromPath('video', video.path));

    if (title != null) request.fields['title'] = title;
    if (description != null) request.fields['description'] = description;
    request.fields['published'] = published.toString();

    final streamedResponse = await _client.send(request);
    final response = await http.Response.fromStream(streamedResponse);
    return _handleResponse(response);
  }

  // Post Management Methods
  Future<List<dynamic>> getPagePosts({
    required String pageId,
    required String businessId,
    int? limit,
    String? fields,
    String? userId,
    String? token,
  }) async {
    final uri = Uri.parse(ApiConfig.getFacebookPagePosts(pageId));
    final queryParams = <String, String>{};
    if (limit != null) queryParams['limit'] = limit.toString();
    if (fields != null) queryParams['fields'] = fields;

    final response = await _client.get(
      uri.replace(queryParameters: queryParams.isNotEmpty ? queryParams : null),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response)['data'] ?? [];
  }

  Future<Map<String, dynamic>> deletePost({
    required String postId,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.delete(
      Uri.parse(ApiConfig.getFacebookPost(postId)),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  // Social Interaction Methods
  Future<Map<String, dynamic>> toggleLike({
    required String postId,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.getFacebookPostLike(postId)),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> addReaction({
    required String postId,
    required String reactionType,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.getFacebookPostReactions(postId)),
      headers: await _getHeaders(businessId, userId: userId, token: token),
      body: jsonEncode({
        'type': reactionType,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> commentOnPost({
    required String postId,
    required String message,
    required String businessId,
    String? pageId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.getFacebookPostComments(postId)),
      headers: await _getHeaders(businessId, userId: userId, token: token),
      body: jsonEncode({
        'message': message,
        if (pageId != null) 'pageId': pageId,
      }),
    );
    return _handleResponse(response);
  }

  // Messaging Methods
  Future<Map<String, dynamic>> sendMessage({
    required String pageId,
    required String recipientId,
    required String message,
    required String businessId,
    String? userId,
    String? token,
  }) async {
    final response = await _client.post(
      Uri.parse(ApiConfig.getFacebookMessagesSend()),
      headers: await _getHeaders(businessId, userId: userId, token: token),
      body: jsonEncode({
        'pageId': pageId,
        'recipientId': recipientId,
        'message': message,
      }),
    );
    return _handleResponse(response);
  }

  Future<List<dynamic>> getConversationMessages({
    required String conversationId,
    required String businessId,
    int? limit,
    String? userId,
    String? token,
  }) async {
    final uri =
        Uri.parse(ApiConfig.getFacebookConversationMessages(conversationId));
    final queryParams = <String, String>{};
    if (limit != null) queryParams['limit'] = limit.toString();

    final response = await _client.get(
      uri.replace(queryParameters: queryParams.isNotEmpty ? queryParams : null),
      headers: await _getHeaders(businessId, userId: userId, token: token),
    );
    return _handleResponse(response)['data'] ?? [];
  }

  // Utility Methods
  void dispose() {
    _client.close();
  }

  // Constants for reaction types
  static const List<String> reactionTypes = [
    'LIKE',
    'LOVE',
    'WOW',
    'HAHA',
    'SAD',
    'ANGRY',
  ];

  // Helper method to validate reaction type
  static bool isValidReactionType(String type) {
    return reactionTypes.contains(type.toUpperCase());
  }
}
