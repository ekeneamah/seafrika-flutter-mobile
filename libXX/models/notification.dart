import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  booking,
  order,
  inventory,
  message,
  system,
}

enum NotificationPriority {
  low,
  medium,
  high,
}

class AppNotification {
  final String id;
  final String vendorId;
  final String title;
  final String message;
  final NotificationType type;
  final NotificationPriority priority;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.vendorId,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'vendorId': vendorId,
      'title': title,
      'message': message,
      'type': type.toString(),
      'priority': priority.toString(),
      'data': data,
      'isRead': isRead,
      'createdAt': createdAt,
    };
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic> map) {
    return AppNotification(
      id: id,
      vendorId: map['vendorId'] as String,
      title: map['title'] as String,
      message: map['message'] as String,
      type: NotificationType.values.firstWhere(
        (e) => e.toString() == map['type'],
      ),
      priority: NotificationPriority.values.firstWhere(
        (e) => e.toString() == map['priority'],
      ),
      data: map['data'] as Map<String, dynamic>?,
      isRead: map['isRead'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  AppNotification copyWith({
    String? title,
    String? message,
    NotificationType? type,
    NotificationPriority? priority,
    Map<String, dynamic>? data,
    bool? isRead,
  }) {
    return AppNotification(
      id: id,
      vendorId: vendorId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
    );
  }
}
