import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/notification.dart';
import 'package:vendor_app/services/auth_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/notification_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _showUnreadOnly = false;
  DocumentSnapshot? _lastDocument;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _toggleUnreadOnly,
          ),
          IconButton(
            icon: const Icon(Icons.done_all),
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: context.read<NotificationService>().streamNotifications(
              unreadOnly: _showUnreadOnly,
              lastDocument: _lastDocument,
            ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return error.ErrorView(
              message: 'Failed to load notifications',
              onRetry: () {
                setState(() {
                  _lastDocument = null;
                  _hasMore = true;
                });
              },
            );
          }

          if (!snapshot.hasData) {
            return const LoadingView();
          }

          final notifications = snapshot.data!;

          if (notifications.isEmpty) {
            return Center(
              child: Text(
                _showUnreadOnly
                    ? 'No unread notifications'
                    : 'No notifications',
              ),
            );
          }

          return ListView.builder(
            itemCount: notifications.length + (_hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == notifications.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final notification = notifications[index];
              return _buildNotificationItem(notification);
            },
          );
        },
      ),
    );
  }

  void _toggleUnreadOnly() {
    setState(() {
      _showUnreadOnly = !_showUnreadOnly;
      _lastDocument = null;
      _hasMore = true;
    });
  }

  Future<void> _markAllAsRead() async {
    try {
      String vendorId = context.read<AuthService>().currentUser?.vendorId ?? '';
      await context.read<NotificationService>().markAllAsRead(vendorId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All notifications marked as read')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark notifications as read')),
        );
      }
    }
  }

  Widget _buildNotificationItem(AppNotification notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (direction) => _deleteNotification(notification),
      child: ListTile(
        leading: _buildNotificationIcon(notification),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight:
                notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Text(notification.message),
        trailing: notification.isRead
            ? null
            : IconButton(
                icon: const Icon(Icons.check),
                onPressed: () => _markAsRead(notification),
              ),
        onTap: () => _onNotificationTap(notification),
      ),
    );
  }

  Widget _buildNotificationIcon(AppNotification notification) {
    IconData icon;
    Color color;

    switch (notification.type) {
      case NotificationType.booking:
        icon = Icons.calendar_today;
        color = Colors.blue;
        break;
      case NotificationType.order:
        icon = Icons.shopping_cart;
        color = Colors.green;
        break;
      case NotificationType.inventory:
        icon = Icons.inventory;
        color = Colors.orange;
        break;
      case NotificationType.message:
        icon = Icons.message;
        color = Colors.purple;
        break;
      case NotificationType.system:
        icon = Icons.info;
        color = Colors.grey;
        break;
    }

    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color),
    );
  }

  Future<void> _markAsRead(AppNotification notification) async {
    try {
      String vendorId = context.read<AuthService>().currentUser?.vendorId ?? '';
      await context
          .read<NotificationService>()
          .markAsRead(notification.id, vendorId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark notification as read')),
        );
      }
    }
  }

  Future<void> _deleteNotification(AppNotification notification) async {
    try {
      String vendorId = context.read<AuthService>().currentUser?.vendorId ?? '';
      await context
          .read<NotificationService>()
          .deleteNotification(notification.id, vendorId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete notification')),
        );
      }
    }
  }

  void _onNotificationTap(AppNotification notification) {
    NavigationService.navigateToNotificationDetail(notification.id);
  }
}
