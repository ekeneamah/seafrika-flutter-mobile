import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/message.dart';

/// Service to manage offline message queue
class OfflineMessageQueue {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Queue a message for later sending
  Future<String> queueMessage({
    required String messageId,
    required String conversationId,
    required String businessId,
    required String integrationId,
    required String platform,
    required String recipientId,
    String? message,
    String? messageType,
    String? attachmentUrl,
    Map<String, dynamic>? metadata,
    String? reason,
  }) async {
    try {
      final queueRef = _firestore.collection('message_queue').doc();
      final now = DateTime.now();
      final nextRetryAt = now.add(const Duration(minutes: 1));

      await queueRef.set({
        'messageId': messageId,
        'conversationId': conversationId,
        'businessId': businessId,
        'integrationId': integrationId,
        'platform': platform,
        'recipientId': recipientId,
        'message': message,
        'messageType': messageType ?? 'text',
        'attachmentUrl': attachmentUrl,
        'metadata': metadata ?? {},
        'reason': reason ?? 'offline',
        'status': 'queued',
        'retryCount': 0,
        'maxRetries': 5,
        'nextRetryAt': Timestamp.fromDate(nextRetryAt),
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      // Update message status in main messages collection
      await _firestore.collection('messages').doc(messageId).update({
        'metadata.status': 'queued',
        'metadata.queuedAt': Timestamp.fromDate(now),
        'metadata.queueId': queueRef.id,
        'updatedAt': Timestamp.fromDate(now),
      });

      debugPrint('✅ Message queued: $messageId (queueId: ${queueRef.id})');
      return queueRef.id;
    } catch (e) {
      debugPrint('❌ Error queueing message: $e');
      rethrow;
    }
  }

  /// Get all queued messages for a business
  Future<List<QueuedMessage>> getBusinessQueue(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('message_queue')
          .where('businessId', isEqualTo: businessId)
          .where('status', whereIn: ['queued', 'retrying'])
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => QueuedMessage.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting business queue: $e');
      return [];
    }
  }

  /// Get queued messages for a specific conversation
  Future<List<QueuedMessage>> getConversationQueue(
      String conversationId) async {
    try {
      final snapshot = await _firestore
          .collection('message_queue')
          .where('conversationId', isEqualTo: conversationId)
          .where('status', whereIn: ['queued', 'retrying'])
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs
          .map((doc) => QueuedMessage.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('❌ Error getting conversation queue: $e');
      return [];
    }
  }

  /// Listen to queue changes for a business in real-time
  Stream<List<QueuedMessage>> watchBusinessQueue(String businessId) {
    return _firestore
        .collection('message_queue')
        .where('businessId', isEqualTo: businessId)
        .where('status', whereIn: ['queued', 'retrying'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QueuedMessage.fromFirestore(doc))
            .toList());
  }

  /// Listen to queue changes for a conversation in real-time
  Stream<List<QueuedMessage>> watchConversationQueue(String conversationId) {
    return _firestore
        .collection('message_queue')
        .where('conversationId', isEqualTo: conversationId)
        .where('status', whereIn: ['queued', 'retrying'])
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => QueuedMessage.fromFirestore(doc))
            .toList());
  }

  /// Get count of queued messages for a business
  Future<int> getQueueCount(String businessId) async {
    try {
      final snapshot = await _firestore
          .collection('message_queue')
          .where('businessId', isEqualTo: businessId)
          .where('status', whereIn: ['queued', 'retrying'])
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('❌ Error getting queue count: $e');
      return 0;
    }
  }

  /// Watch queue count for a business in real-time
  Stream<int> watchQueueCount(String businessId) {
    return _firestore
        .collection('message_queue')
        .where('businessId', isEqualTo: businessId)
        .where('status', whereIn: ['queued', 'retrying'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}

/// Model class for queued messages
class QueuedMessage {
  final String id;
  final String messageId;
  final String conversationId;
  final String businessId;
  final String integrationId;
  final String platform;
  final String recipientId;
  final String? message;
  final String messageType;
  final String? attachmentUrl;
  final Map<String, dynamic>? metadata;
  final String reason;
  final String status;
  final int retryCount;
  final int maxRetries;
  final DateTime nextRetryAt;
  final String? lastError;
  final DateTime createdAt;
  final DateTime updatedAt;

  QueuedMessage({
    required this.id,
    required this.messageId,
    required this.conversationId,
    required this.businessId,
    required this.integrationId,
    required this.platform,
    required this.recipientId,
    this.message,
    required this.messageType,
    this.attachmentUrl,
    this.metadata,
    required this.reason,
    required this.status,
    required this.retryCount,
    required this.maxRetries,
    required this.nextRetryAt,
    this.lastError,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QueuedMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return QueuedMessage(
      id: doc.id,
      messageId: data['messageId'] ?? '',
      conversationId: data['conversationId'] ?? '',
      businessId: data['businessId'] ?? '',
      integrationId: data['integrationId'] ?? '',
      platform: data['platform'] ?? '',
      recipientId: data['recipientId'] ?? '',
      message: data['message'],
      messageType: data['messageType'] ?? 'text',
      attachmentUrl: data['attachmentUrl'],
      metadata: data['metadata'] != null
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
      reason: data['reason'] ?? 'offline',
      status: data['status'] ?? 'queued',
      retryCount: data['retryCount'] ?? 0,
      maxRetries: data['maxRetries'] ?? 5,
      nextRetryAt:
          (data['nextRetryAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastError: data['lastError'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'conversationId': conversationId,
      'businessId': businessId,
      'integrationId': integrationId,
      'platform': platform,
      'recipientId': recipientId,
      'message': message,
      'messageType': messageType,
      'attachmentUrl': attachmentUrl,
      'metadata': metadata,
      'reason': reason,
      'status': status,
      'retryCount': retryCount,
      'maxRetries': maxRetries,
      'nextRetryAt': Timestamp.fromDate(nextRetryAt),
      'lastError': lastError,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  bool get canRetry => retryCount < maxRetries && status != 'sent';

  bool get isPending => status == 'queued' || status == 'retrying';

  bool get hasFailed => status == 'failed' || retryCount >= maxRetries;
}
