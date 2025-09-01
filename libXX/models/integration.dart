import 'package:cloud_firestore/cloud_firestore.dart';

class Integration {
  final String id;
  final String platformId;
  final String platformName;
  final String platformIcon;
  final String status;
  final DateTime createdAt;
  final IntegrationSettings settings;

  Integration({
    required this.id,
    required this.platformId,
    required this.platformName,
    required this.platformIcon,
    required this.status,
    required this.createdAt,
    required this.settings,
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
    };
  }
}

class IntegrationSettings {
  final bool autoSync;
  final int syncInterval;
  final bool syncInventory;
  final bool syncOrders;
  final bool syncProducts;

  IntegrationSettings({
    required this.autoSync,
    required this.syncInterval,
    required this.syncInventory,
    required this.syncOrders,
    required this.syncProducts,
  });

  factory IntegrationSettings.fromMap(Map<String, dynamic> map) {
    return IntegrationSettings(
      autoSync: map['autoSync'] as bool,
      syncInterval: map['syncInterval'] as int,
      syncInventory: map['syncInventory'] as bool,
      syncOrders: map['syncOrders'] as bool,
      syncProducts: map['syncProducts'] as bool,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'autoSync': autoSync,
      'syncInterval': syncInterval,
      'syncInventory': syncInventory,
      'syncOrders': syncOrders,
      'syncProducts': syncProducts,
    };
  }
}
