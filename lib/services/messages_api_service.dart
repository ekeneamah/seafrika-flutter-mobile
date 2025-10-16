import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../config/api_config.dart';
import 'offline_message_queue.dart';
import 'connectivity_service.dart';

/// Service for sending messages via backend API
///
/// This service handles HTTP calls to the backend to send messages
/// through various platforms (Messenger, Instagram, WhatsApp).
/// It follows the established pattern of other services in the app.
///
/// **NEW**: Includes offline queue support - messages are automatically queued
/// when offline or when sending fails, and retried when connection is restored.
class MessagesApiService {
  final _storage = const FlutterSecureStorage();
  final http.Client _client;
  final OfflineMessageQueue _queue = OfflineMessageQueue();
  final ConnectivityService _connectivityService = ConnectivityService();

  MessagesApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Get headers with authentication token
  Future<Map<String, String>> _getHeaders({String? token}) async {
    final authToken = token ?? await _storage.read(key: 'auth_token') ?? '';

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $authToken',
    };
  }

  /// Handle HTTP response
  dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body);
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Send a message via Messenger with offline queue support
  ///
  /// Parameters:
  /// - [integrationId]: The integration ID from Firestore
  /// - [messageId]: The Firestore message document ID
  /// - [conversationId]: The Firestore conversation ID
  /// - [recipientId]: The recipient's Facebook/Messenger PSID
  /// - [businessId]: The business/vendor ID
  /// - [message]: The message text content
  /// - [messageType]: Type of message (text, image, video, audio, file)
  /// - [attachmentUrl]: URL of attachment (required for non-text messages)
  /// - [metadata]: Optional metadata for the message
  /// - [token]: Optional auth token (otherwise uses stored token)
  ///
  /// Returns: Map with success status, message_id, recipient_id, and messageId
  ///
  /// **Offline Support**: If device is offline or request fails, message is
  /// automatically queued and will be retried when connection is restored.
  Future<Map<String, dynamic>> sendMessengerMessage({
    required String integrationId,
    required String messageId,
    required String conversationId,
    required String recipientId,
    required String businessId,
    required String message,
    String messageType = 'text',
    String? attachmentUrl,
    Map<String, dynamic>? metadata,
    String? token,
  }) async {
    // Check if device is offline
    final isOnline = await _connectivityService.checkConnectivity();

    if (!isOnline) {
      // Queue message for later sending
      await _queue.queueMessage(
        messageId: messageId,
        conversationId: conversationId,
        businessId: businessId,
        integrationId: integrationId,
        platform: 'messenger',
        recipientId: recipientId,
        message: message,
        messageType: messageType,
        attachmentUrl: attachmentUrl,
        metadata: metadata,
        reason: 'offline',
      );

      return {
        'success': false,
        'queued': true,
        'messageId': messageId,
        'reason': 'Device is offline - message queued for retry',
      };
    }

    try {
      final url = ApiConfig.getMessengerSendMessage(integrationId);

      final body = {
        'messageId': messageId,
        'conversationId': conversationId,
        'recipientId': recipientId,
        'message': message,
        'messageType': messageType,
        if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      };

      final response = await _client.post(
        Uri.parse(url),
        headers: await _getHeaders(token: token),
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      // If send fails, queue for retry
      await _queue.queueMessage(
        messageId: messageId,
        conversationId: conversationId,
        businessId: businessId,
        integrationId: integrationId,
        platform: 'messenger',
        recipientId: recipientId,
        message: message,
        messageType: messageType,
        attachmentUrl: attachmentUrl,
        metadata: metadata,
        reason: 'send_failed: $e',
      );

      return {
        'success': false,
        'queued': true,
        'messageId': messageId,
        'reason': 'Send failed - message queued for retry',
        'error': e.toString(),
      };
    }
  }

  /// Send a direct message via Instagram with offline queue support
  ///
  /// Parameters:
  /// - [integrationId]: The integration ID from Firestore
  /// - [messageId]: The Firestore message document ID
  /// - [conversationId]: The Firestore conversation ID
  /// - [recipientId]: The recipient's Instagram Scoped ID (IGSID)
  /// - [businessId]: The business/vendor ID
  /// - [message]: The message text content
  /// - [messageType]: Type of message (text, image, video)
  /// - [attachmentUrl]: URL of attachment (required for non-text messages)
  /// - [metadata]: Optional metadata for the message
  /// - [token]: Optional auth token (otherwise uses stored token)
  ///
  /// Returns: Map with success status, message_id, recipient_id, and messageId
  ///
  /// **Offline Support**: If device is offline or request fails, message is
  /// automatically queued and will be retried when connection is restored.
  Future<Map<String, dynamic>> sendInstagramMessage({
    required String integrationId,
    required String messageId,
    required String conversationId,
    required String recipientId,
    required String businessId,
    required String message,
    String messageType = 'text',
    String? attachmentUrl,
    Map<String, dynamic>? metadata,
    String? token,
  }) async {
    // Check if device is offline
    final isOnline = await _connectivityService.checkConnectivity();

    if (!isOnline) {
      // Queue message for later sending
      await _queue.queueMessage(
        messageId: messageId,
        conversationId: conversationId,
        businessId: businessId,
        integrationId: integrationId,
        platform: 'instagram',
        recipientId: recipientId,
        message: message,
        messageType: messageType,
        attachmentUrl: attachmentUrl,
        metadata: metadata,
        reason: 'offline',
      );

      return {
        'success': false,
        'queued': true,
        'messageId': messageId,
        'reason': 'Device is offline - message queued for retry',
      };
    }

    try {
      final url = ApiConfig.getInstagramSendMessage(integrationId);

      final body = {
        'messageId': messageId,
        'conversationId': conversationId,
        'recipientId': recipientId,
        'message': message,
        'messageType': messageType,
        if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      };

      final response = await _client.post(
        Uri.parse(url),
        headers: await _getHeaders(token: token),
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      // If send fails, queue for retry
      await _queue.queueMessage(
        messageId: messageId,
        conversationId: conversationId,
        businessId: businessId,
        integrationId: integrationId,
        platform: 'instagram',
        recipientId: recipientId,
        message: message,
        messageType: messageType,
        attachmentUrl: attachmentUrl,
        metadata: metadata,
        reason: 'send_failed: $e',
      );

      return {
        'success': false,
        'queued': true,
        'messageId': messageId,
        'reason': 'Send failed - message queued for retry',
        'error': e.toString(),
      };
    }
  }

  /// Send a message to the appropriate platform with offline queue support
  ///
  /// This is a convenience method that routes to the correct platform-specific
  /// send method based on the platform parameter.
  ///
  /// Parameters:
  /// - [platform]: Platform to send to ('messenger', 'instagram', 'whatsapp')
  /// - [integrationId]: The integration ID from Firestore
  /// - [messageId]: The Firestore message document ID
  /// - [conversationId]: The Firestore conversation ID
  /// - [recipientId]: The recipient's platform-specific ID
  /// - [businessId]: The business/vendor ID
  /// - [message]: The message text content
  /// - [messageType]: Type of message (text, image, video, etc.)
  /// - [attachmentUrl]: URL of attachment (required for non-text messages)
  /// - [metadata]: Optional metadata for the message
  /// - [token]: Optional auth token (otherwise uses stored token)
  ///
  /// Returns: Map with success status, message_id, recipient_id, and messageId.
  /// If offline or send fails, returns {success: false, queued: true, ...}
  Future<Map<String, dynamic>> sendMessage({
    required String platform,
    required String integrationId,
    required String messageId,
    required String conversationId,
    required String recipientId,
    required String businessId,
    required String message,
    String messageType = 'text',
    String? attachmentUrl,
    Map<String, dynamic>? metadata,
    String? token,
  }) async {
    switch (platform.toLowerCase()) {
      case 'messenger':
      case 'facebook':
        return sendMessengerMessage(
          integrationId: integrationId,
          messageId: messageId,
          conversationId: conversationId,
          recipientId: recipientId,
          businessId: businessId,
          message: message,
          messageType: messageType,
          attachmentUrl: attachmentUrl,
          metadata: metadata,
          token: token,
        );

      case 'instagram':
        return sendInstagramMessage(
          integrationId: integrationId,
          messageId: messageId,
          conversationId: conversationId,
          recipientId: recipientId,
          businessId: businessId,
          message: message,
          messageType: messageType,
          attachmentUrl: attachmentUrl,
          metadata: metadata,
          token: token,
        );

      default:
        throw Exception(
            'Unsupported platform: $platform. Supported platforms are: messenger, instagram');
    }
  }

  /// Dispose of the HTTP client
  void dispose() {
    _client.close();
  }
}
