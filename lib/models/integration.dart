import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

// Messaging statistics for integration (Tier 1 in 3-tier structure)
class MessagingStats {
  final int totalNewMessages;
  final int totalMessageCount;
  final DateTime? lastMessageDate;
  final String? lastMessageId;
  final String? lastMessagePreview;
  final int totalConversations;
  final int activeConversations;

  MessagingStats({
    this.totalNewMessages = 0,
    this.totalMessageCount = 0,
    this.lastMessageDate,
    this.lastMessageId,
    this.lastMessagePreview,
    this.totalConversations = 0,
    this.activeConversations = 0,
  });

  factory MessagingStats.fromMap(Map<String, dynamic> map) {
    return MessagingStats(
      totalNewMessages: map['totalNewMessages'] as int? ?? 0,
      totalMessageCount: map['totalMessageCount'] as int? ?? 0,
      lastMessageDate: map['lastMessageDate'] is Timestamp
          ? (map['lastMessageDate'] as Timestamp).toDate()
          : map['lastMessageDate'] != null
              ? DateTime.parse(map['lastMessageDate'] as String)
              : null,
      lastMessageId: map['lastMessageId'] as String?,
      lastMessagePreview: map['lastMessagePreview'] as String?,
      totalConversations: map['totalConversations'] as int? ?? 0,
      activeConversations: map['activeConversations'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'totalNewMessages': totalNewMessages,
      'totalMessageCount': totalMessageCount,
      'lastMessageDate': lastMessageDate,
      'lastMessageId': lastMessageId,
      'lastMessagePreview': lastMessagePreview,
      'totalConversations': totalConversations,
      'activeConversations': activeConversations,
    };
  }
}

class Integration {
  final String id;
  final String platformId;
  final String platformName;
  final String platformIcon;
  final String channel;
  final String status;
  final DateTime createdAt;
  final IntegrationSettings settings;
  final Map<String, dynamic>? credentials;
  final String? errorMessage;
  final Map<String, dynamic>? accountInfo;
  final MessagingStats? messagingStats; // NEW: Messaging statistics

  Integration({
    required this.id,
    required this.platformId,
    required this.platformName,
    required this.platformIcon,
    required this.channel,
    required this.status,
    required this.createdAt,
    required this.settings,
    this.credentials,
    this.errorMessage,
    this.accountInfo,
    this.messagingStats, // NEW: Optional messaging stats
  });

  factory Integration.fromMap(Map<String, dynamic> map) {
    return Integration(
      id: map['id'] as String,
      platformId: map['platformId'] as String,
      platformName: map['platformName'] as String,
      platformIcon: map['platformIcon'] as String,
      channel: map['channel'] as String,
      status: map['status'] as String,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.parse(map['createdAt'] as String),
      settings:
          IntegrationSettings.fromMap(map['settings'] as Map<String, dynamic>),
      credentials: map['credentials'] as Map<String, dynamic>?,
      errorMessage: map['error_message'] as String?,
      accountInfo: map['accountInfo'] as Map<String, dynamic>?,
      messagingStats: map['messagingStats'] != null
          ? MessagingStats.fromMap(
              map['messagingStats'] as Map<String, dynamic>)
          : null,
    );
  }

  factory Integration.fromJson(Map<String, dynamic> json) {
    return Integration(
      id: json['id'] as String,
      platformId: json['platformId'] as String,
      platformName: json['platformName'] as String,
      platformIcon: json['platformIcon'] as String,
      channel: json['channel'] as String,
      status: json['status'] as String,
      createdAt: json['createdAt'] is Timestamp
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.parse(json['createdAt'] as String),
      settings:
          IntegrationSettings.fromMap(json['settings'] as Map<String, dynamic>),
      credentials: json['credentials'] as Map<String, dynamic>?,
      errorMessage: json['error_message'] as String?,
      accountInfo: json['accountInfo'] as Map<String, dynamic>?,
      messagingStats: json['messagingStats'] != null
          ? MessagingStats.fromMap(
              json['messagingStats'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'platformId': platformId,
      'platformName': platformName,
      'platformIcon': platformIcon,
      'channel': channel,
      'status': status,
      'createdAt': createdAt,
      'settings': settings.toMap(),
      'credentials': credentials,
      'error_message': errorMessage,
      'accountInfo': accountInfo,
      'messagingStats': messagingStats?.toMap(),
    };
  }

  // Helper method to get page name from accountInfo
  String? get pageName => accountInfo?['pageName'] as String?;

  // Helper method to get Instagram username from accountInfo
  String? get instagramUsername => accountInfo?['instagramUsername'] as String?;

  // Helper method to get TikTok display name from accountInfo
  String? get tikTokDisplayName => accountInfo?['displayName'] as String?;

  // Helper method to get TikTok username from accountInfo
  String? get tikTokUsername => accountInfo?['username'] as String?;

  // Helper method to get YouTube channel title from accountInfo
  String? get youTubeTitle {
    try {
      return accountInfo?['title'] as String?;
    } catch (e) {
      debugPrint('Error accessing youTubeTitle: $e');
      return null;
    }
  }

  // Helper method to get YouTube custom URL from accountInfo
  String? get youTubeCustomUrl {
    try {
      return accountInfo?['customUrl'] as String?;
    } catch (e) {
      debugPrint('Error accessing youTubeCustomUrl: $e');
      return null;
    }
  }
}

class IntegrationSettings {
  final bool autoSync;
  final int syncInterval;
  final bool syncInventory;
  final bool syncOrders;
  final bool syncProducts;

  // Review & Feedback specific settings
  final bool syncReviews;
  final bool syncRatings;
  final bool autoRespondReviews;
  final bool notifyNewReviews;
  final bool syncCustomerFeedback;

  IntegrationSettings({
    required this.autoSync,
    required this.syncInterval,
    required this.syncInventory,
    required this.syncOrders,
    required this.syncProducts,
    this.syncReviews = false,
    this.syncRatings = false,
    this.autoRespondReviews = false,
    this.notifyNewReviews = true,
    this.syncCustomerFeedback = false,
  });

  factory IntegrationSettings.fromMap(Map<String, dynamic> map) {
    return IntegrationSettings(
      autoSync: map['autoSync'] as bool,
      syncInterval: map['syncInterval'] as int,
      syncInventory: map['syncInventory'] as bool? ?? false,
      syncOrders: map['syncOrders'] as bool? ?? false,
      syncProducts: map['syncProducts'] as bool? ?? false,
      syncReviews: map['syncReviews'] as bool? ?? false,
      syncRatings: map['syncRatings'] as bool? ?? false,
      autoRespondReviews: map['autoRespondReviews'] as bool? ?? false,
      notifyNewReviews: map['notifyNewReviews'] as bool? ?? true,
      syncCustomerFeedback: map['syncCustomerFeedback'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autoSync': autoSync,
      'syncInterval': syncInterval,
      'syncInventory': syncInventory,
      'syncOrders': syncOrders,
      'syncProducts': syncProducts,
      'syncReviews': syncReviews,
      'syncRatings': syncRatings,
      'autoRespondReviews': autoRespondReviews,
      'notifyNewReviews': notifyNewReviews,
      'syncCustomerFeedback': syncCustomerFeedback,
    };
  }
}
