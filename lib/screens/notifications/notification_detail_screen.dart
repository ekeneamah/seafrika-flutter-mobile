import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/models/notification.dart';
import 'package:vendor_app/services/auth_service.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/notification_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class NotificationDetailScreen extends StatefulWidget {
  final String notificationId;

  const NotificationDetailScreen({
    super.key,
    required this.notificationId,
  });

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  bool _isLoading = true;
  AppNotification? _notification;

  @override
  void initState() {
    super.initState();
    _loadNotification();
  }

  Future<void> _loadNotification() async {
    String vendorId = context.read<AuthService>().currentUser?.vendorId ?? '';
    try {
      final notification = await context
          .read<NotificationService>()
          .fetchNotification(widget.notificationId, vendorId);

      if (!notification.isRead) {
        await context
            .read<NotificationService>()
            .markAsRead(widget.notificationId, vendorId);
      }

      if (mounted) {
        setState(() {
          _notification = notification;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load notification')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteNotification,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingView()
          : _notification == null
              ? error.ErrorView(
                  message: 'Notification not found',
                  onRetry: _loadNotification,
                )
              : _buildNotificationDetails(),
    );
  }

  Widget _buildNotificationDetails() {
    final notification = _notification!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(notification),
          const SizedBox(height: 24),
          _buildContent(notification),
          if (notification.data != null && notification.data!.isNotEmpty) ...[
            const SizedBox(height: 24),
            _buildAdditionalData(notification),
          ],
          const SizedBox(height: 24),
          _buildActions(notification),
        ],
      ),
    );
  }

  Widget _buildHeader(AppNotification notification) {
    return Row(
      children: [
        _buildNotificationIcon(notification),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                _formatDate(notification.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContent(AppNotification notification) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Message',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(notification.message),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalData(AppNotification notification) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Additional Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ...notification.data!.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${entry.key}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: Text(entry.value.toString()),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(AppNotification notification) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildActionButton(
              icon: Icons.arrow_forward,
              label: 'View Details',
              onPressed: () => _handleAction(notification),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
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
      radius: 24,
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color, size: 24),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

  void _handleAction(AppNotification notification) {
    switch (notification.type) {
      case NotificationType.booking:
        if (notification.data?['bookingId'] != null) {
          NavigationService.navigateToBookingDetail(
            notification.data!['bookingId'],
          );
        }
        break;
      case NotificationType.order:
        if (notification.data?['orderId'] != null) {
          NavigationService.navigateToOrderDetail(
            notification.data!['orderId'],
          );
        }
        break;
      case NotificationType.inventory:
        if (notification.data?['inventoryId'] != null) {
          NavigationService.navigateToInventoryDetail(
            notification.data!['inventoryId'],
          );
        }
        break;
      case NotificationType.message:
        if (notification.data?['messageId'] != null) {
          NavigationService.navigateTo(
            AppRoutes.notificationDetail,
            arguments: {'notificationId': notification.data!['messageId']},
          );
        }
        break;
      case NotificationType.system:
        // No specific action for system notifications
        break;
    }
  }

  Future<void> _deleteNotification() async {
    String vendorId = context.read<AuthService>().currentUser?.vendorId ?? '';
    try {
      await context
          .read<NotificationService>()
          .deleteNotification(widget.notificationId, vendorId);
      if (mounted) {
        Navigator.of(context).pop();
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
}
