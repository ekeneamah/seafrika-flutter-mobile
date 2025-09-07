import 'package:cloud_firestore/cloud_firestore.dart';

class Integration {
  final String id;
  final String platformId;
  final String platformName;
  final String platformIcon;
  final String status;
  final DateTime createdAt;
  final IntegrationSettings settings;
  final Map<String, dynamic>? credentials;

  Integration({
    required this.id,
    required this.platformId,
    required this.platformName,
    required this.platformIcon,
    required this.status,
    required this.createdAt,
    required this.settings,
    this.credentials,
  });

  factory Integration.fromMap(Map<String, dynamic> map) {
    return Integration(
      id: map['id'] as String,
      platformId: map['platformId'] as String,
      platformName: map['platformName'] as String,
      platformIcon: map['platformIcon'] as String,
      status: map['status'] as String,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      settings:
          IntegrationSettings.fromMap(map['settings'] as Map<String, dynamic>),
      credentials: map['credentials'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'platformId': platformId,
      'platformName': platformName,
      'platformIcon': platformIcon,
      'status': status,
      'createdAt': createdAt,
      'settings': settings.toMap(),
      'credentials': credentials,
    };
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
