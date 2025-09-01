import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:vendor_app/models/notification.dart';
import 'package:vendor_app/services/analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/services/firestore_service.dart';

class NotificationService {
  final AnalyticsService _analytics;
  final FirebaseFirestore _firestore;
  final FirestoreService _firestoreService;
  String _vendorId = '';

  NotificationService({
    required AnalyticsService analytics,
    required FirebaseFirestore firestore,
    required FirestoreService firestoreService,
    required String vendorId,
  })  : _analytics = analytics,
        _firestore = firestore,
        _firestoreService = firestoreService {
    initialize();
  }

  Future<void> initialize() async {
    await AwesomeNotifications().initialize(
      null, // null means use default app icon
      [
        NotificationChannel(
          channelKey: 'basic_channel',
          channelName: 'Basic Notifications',
          channelDescription: 'Basic notification channel',
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
        NotificationChannel(
          channelKey: 'scheduled_channel',
          channelName: 'Scheduled Notifications',
          channelDescription: 'Scheduled notification channel',
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
      ],
    );

    // Initialize timezone
    tz.initializeTimeZones();
  }

  Future<void> requestPermission() async {
    await AwesomeNotifications().isNotificationAllowed().then((isAllowed) {
      if (!isAllowed) {
        AwesomeNotifications().requestPermissionToSendNotifications();
      }
    });
  }

  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
    NotificationLayout layout = NotificationLayout.Default,
    String? vendorId,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'basic_channel',
        title: title,
        body: body,
        payload: {'data': payload ?? ''},
        notificationLayout: layout,
      ),
    );
  }

  Future<void> scheduleNotification({
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    NotificationLayout layout = NotificationLayout.Default,
  }) async {
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
        channelKey: 'scheduled_channel',
        title: title,
        body: body,
        payload: {'data': payload ?? ''},
        notificationLayout: layout,
      ),
      schedule: NotificationCalendar.fromDate(
        date: scheduledDate,
        allowWhileIdle: true,
        preciseAlarm: true,
      ),
    );
  }

  Future<void> cancelNotification(int id) async {
    await AwesomeNotifications().cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
  }

  void setListeners({
    required Future<void> Function(ReceivedAction) onActionReceivedMethod,
    required Future<void> Function(ReceivedNotification)
        onNotificationCreatedMethod,
    required Future<void> Function(ReceivedNotification)
        onNotificationDisplayedMethod,
    required Future<void> Function(ReceivedAction)
        onDismissActionReceivedMethod,
  }) {
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );
  }

  Stream<List<AppNotification>> streamNotifications({
    bool? unreadOnly,
    DocumentSnapshot? lastDocument,
    int limit = 20,
    String? vendorId,
  }) {
    Query query = _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (unreadOnly == true) {
      query = query.where('isRead', isEqualTo: false);
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return AppNotification.fromMap(
            doc.id, doc.data() as Map<String, dynamic>);
      }).toList();
    });
  }

  Future<AppNotification> fetchNotification(
      String notificationId, String vendorId) async {
    final doc = await _firestore
        .collection('vendors')
        .doc(vendorId)
        .collection('notifications')
        .doc(notificationId)
        .get();

    if (!doc.exists) {
      throw Exception('Notification not found');
    }

    return AppNotification.fromMap(doc.id, doc.data() as Map<String, dynamic>);
  }

  Future<AppNotification> sendNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.system,
    NotificationPriority priority = NotificationPriority.medium,
    Map<String, dynamic>? data,
    String? vendorId,
  }) async {
    final notificationRef = _firestore
        .collection('vendors')
        .doc(_firestoreService.currentUserId ?? '')
        .collection('notifications')
        .doc();

    final now = DateTime.now();
    final notification = AppNotification(
      id: notificationRef.id,
      vendorId: _firestoreService.currentUserId ?? '',
      title: title,
      message: message,
      type: type,
      priority: priority,
      data: data,
      isRead: false,
      createdAt: now,
    );

    await notificationRef.set(notification.toMap());
    return notification;
  }

  Future<void> markAsRead(String notificationId, String vendorId) async {
    await _firestore
        .collection('vendors')
        .doc(_firestoreService.currentUserId ?? '')
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead(String vendorId) async {
    final batch = _firestore.batch();
    final notifications = await _firestore
        .collection('vendors')
        .doc(_firestoreService.currentUserId ?? '')
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    for (final doc in notifications.docs) {
      batch.update(doc.reference, {'isRead': true});
    }

    await batch.commit();
  }

  Future<void> deleteNotification(
      String notificationId, String vendorId) async {
    await _firestore
        .collection('vendors')
        .doc(_firestoreService.currentUserId ?? '')
        .collection('notifications')
        .doc(notificationId)
        .delete();
  }

  Future<void> deleteAllNotifications(String vendorId) async {
    final batch = _firestore.batch();
    final notifications = await _firestore
        .collection('vendors')
        .doc(_firestoreService.currentUserId ?? '')
        .collection('notifications')
        .get();

    for (final doc in notifications.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<void> subscribeToTopic(String topic, String vendorId) async {
    await AwesomeNotifications().setChannel(
      NotificationChannel(
        channelKey: topic,
        channelName: topic,
        channelDescription: 'Channel for $topic notifications',
        defaultColor: Colors.blue,
        ledColor: Colors.blue,
        importance: NotificationImportance.High,
      ),
    );
  }

  Future<void> unsubscribeFromTopic(String topic, String vendorId) async {
    await AwesomeNotifications().cancelAllSchedules();
  }

  Future<Map<String, dynamic>> getNotificationStats() async {
    final notifications = await _firestore
        .collection('vendors')
        .doc(_firestoreService.currentUserId ?? '')
        .collection('notifications')
        .get();

    final allNotifications = notifications.docs
        .map((doc) => AppNotification.fromMap(doc.id, doc.data()))
        .toList();

    return {
      'total': allNotifications.length,
      'unread': allNotifications.where((n) => !n.isRead).length,
      'byType': NotificationType.values.map((type) {
        return {
          'type': type.toString(),
          'count': allNotifications.where((n) => n.type == type).length,
        };
      }).toList(),
      'byPriority': NotificationPriority.values.map((priority) {
        return {
          'priority': priority.toString(),
          'count': allNotifications.where((n) => n.priority == priority).length,
        };
      }).toList(),
    };
  }
}
