import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service for managing typing indicators in conversations
///
/// This service handles:
/// - Reading typing status from Firestore (from webhooks)
/// - Writing typing status for business users
/// - Auto-expiring stale typing indicators
///
/// Firestore Structure:
/// businesses/{businessId}/integrations/{integrationId}/conversations/{conversationId}/typing/{userId}
class TypingIndicatorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get stream of users currently typing in a conversation
  ///
  /// Returns a stream that emits list of typing users whenever typing status changes.
  /// Filters out expired typing indicators (older than 5 seconds).
  ///
  /// Example:
  /// ```dart
  /// final typingStream = typingService.getTypingUsers(
  ///   businessId: 'business_123',
  ///   integrationId: 'integration_456',
  ///   conversationId: 'conversation_789',
  /// );
  ///
  /// typingStream.listen((typingUsers) {
  ///   print('${typingUsers.length} users typing');
  /// });
  /// ```
  Stream<List<TypingUser>> getTypingUsers({
    required String businessId,
    required String integrationId,
    required String conversationId,
  }) {
    final typingPath = _firestore
        .collection('businesses')
        .doc(businessId)
        .collection('integrations')
        .doc(integrationId)
        .collection('conversations')
        .doc(conversationId)
        .collection('typing');

    return typingPath.snapshots().map((snapshot) {
      final now = DateTime.now();

      // Filter out expired typing indicators and convert to TypingUser objects
      return snapshot.docs
          .map((doc) {
            try {
              final data = doc.data();
              final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();

              // Check if typing indicator has expired
              if (expiresAt != null && expiresAt.isBefore(now)) {
                // Clean up expired indicator
                _cleanupExpiredTyping(
                  businessId: businessId,
                  integrationId: integrationId,
                  conversationId: conversationId,
                  userId: doc.id,
                );
                return null;
              }

              return TypingUser(
                userId: doc.id,
                userName: data['userName'] as String? ?? 'User',
                platform: data['platform'] as String? ?? 'unknown',
                startedAt: (data['startedAt'] as Timestamp?)?.toDate() ?? now,
              );
            } catch (e) {
              debugPrint('Error parsing typing user: $e');
              return null;
            }
          })
          .where((user) => user != null)
          .cast<TypingUser>()
          .toList();
    });
  }

  /// Set typing status for a business user (when they type in the Flutter app)
  ///
  /// Call this when the business user starts typing.
  /// The typing indicator will auto-expire after 5 seconds.
  ///
  /// Example:
  /// ```dart
  /// // When user starts typing
  /// await typingService.setTyping(
  ///   businessId: 'business_123',
  ///   integrationId: 'integration_456',
  ///   conversationId: 'conversation_789',
  ///   userId: 'business_user_001',
  ///   userName: 'John Doe',
  ///   isTyping: true,
  /// );
  /// ```
  Future<void> setTyping({
    required String businessId,
    required String integrationId,
    required String conversationId,
    required String userId,
    required String userName,
    required bool isTyping,
  }) async {
    try {
      final typingDoc = _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('integrations')
          .doc(integrationId)
          .collection('conversations')
          .doc(conversationId)
          .collection('typing')
          .doc(userId);

      if (isTyping) {
        await typingDoc.set({
          'userId': userId,
          'userName': userName,
          'platform': 'app', // Business user typing from Flutter app
          'isTyping': true,
          'startedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(seconds: 5)),
          ),
          'conversationId': conversationId,
        });
      } else {
        await typingDoc.delete();
      }
    } catch (e) {
      debugPrint('Error setting typing status: $e');
      // Don't throw - typing indicators are non-critical
    }
  }

  /// Clean up expired typing indicator
  ///
  /// Called automatically when expired typing indicators are detected.
  /// Runs in background without blocking.
  Future<void> _cleanupExpiredTyping({
    required String businessId,
    required String integrationId,
    required String conversationId,
    required String userId,
  }) async {
    try {
      await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('integrations')
          .doc(integrationId)
          .collection('conversations')
          .doc(conversationId)
          .collection('typing')
          .doc(userId)
          .delete();

      debugPrint('🧹 Cleaned up expired typing indicator for user: $userId');
    } catch (e) {
      debugPrint('Error cleaning up expired typing indicator: $e');
      // Ignore errors - will be cleaned up on next read
    }
  }

  /// Manually clean up all expired typing indicators for a conversation
  ///
  /// Useful for periodic cleanup or when conversation is opened.
  Future<void> cleanupAllExpiredTyping({
    required String businessId,
    required String integrationId,
    required String conversationId,
  }) async {
    try {
      final now = Timestamp.now();
      final typingSnapshot = await _firestore
          .collection('businesses')
          .doc(businessId)
          .collection('integrations')
          .doc(integrationId)
          .collection('conversations')
          .doc(conversationId)
          .collection('typing')
          .where('expiresAt', isLessThan: now)
          .get();

      // Delete expired documents in batch
      final batch = _firestore.batch();
      for (final doc in typingSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (typingSnapshot.docs.isNotEmpty) {
        debugPrint(
          '🧹 Cleaned up ${typingSnapshot.docs.length} expired typing indicators',
        );
      }
    } catch (e) {
      debugPrint('Error cleaning up all expired typing indicators: $e');
    }
  }
}

/// Represents a user who is currently typing
class TypingUser {
  final String userId;
  final String userName;
  final String platform; // 'messenger', 'instagram', 'whatsapp', 'app'
  final DateTime startedAt;

  TypingUser({
    required this.userId,
    required this.userName,
    required this.platform,
    required this.startedAt,
  });

  /// Get display text for typing indicator
  /// Example: "Instagram User is typing..."
  String get displayText {
    final platformName = _getPlatformDisplayName();
    return platformName.isNotEmpty
        ? '$userName ($platformName) is typing...'
        : '$userName is typing...';
  }

  String _getPlatformDisplayName() {
    switch (platform.toLowerCase()) {
      case 'messenger':
        return 'Messenger';
      case 'instagram':
        return 'Instagram';
      case 'whatsapp':
        return 'WhatsApp';
      case 'app':
        return ''; // Business user - no platform label needed
      default:
        return '';
    }
  }

  @override
  String toString() => displayText;
}
