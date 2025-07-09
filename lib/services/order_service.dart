import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/order.dart' as order_model;
import 'package:vendor_app/services/notification_service.dart';
import 'package:vendor_app/models/notification.dart' as notification;

class OrderService {
  final FirebaseFirestore _firestore;
  final String _vendorId;
  final NotificationService _notificationService;

  OrderService({
    required FirebaseFirestore firestore,
    required String vendorId,
    required NotificationService notificationService,
  })  : _firestore = firestore,
        _vendorId = vendorId,
        _notificationService = notificationService;

  Stream<List<order_model.Order>> streamOrders({
    order_model.OrderStatus? status,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
    DocumentSnapshot? lastDocument,
    int? limit,
  }) {
    Query query = _firestore
        .collection('orders')
        .where('vendorId', isEqualTo: _vendorId)
        .orderBy('createdAt', descending: true);

    if (status != null) {
      query =
          query.where('status', isEqualTo: status.toString().split('.').last);
    }

    if (startDate != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: startDate);
    }

    if (endDate != null) {
      query = query.where('createdAt', isLessThanOrEqualTo: endDate);
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      final orders = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return order_model.Order.fromMap({...data, 'id': doc.id});
      }).toList();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        return orders.where((order) {
          return order.customerName.toLowerCase().contains(query) ||
              order.customerEmail.toLowerCase().contains(query) ||
              order.customerPhone.toLowerCase().contains(query) ||
              order.items.any(
                  (item) => item.productName.toLowerCase().contains(query));
        }).toList();
      }

      return orders;
    });
  }

  Future<order_model.Order> fetchOrder(String orderId) async {
    final doc = await _firestore.collection('orders').doc(orderId).get();
    if (!doc.exists) {
      throw Exception('Order not found');
    }
    return order_model.Order.fromMap({...doc.data()!, 'id': doc.id});
  }

  Future<void> updateOrderStatus(
    String orderId,
    order_model.OrderStatus status,
  ) async {
    final order = await fetchOrder(orderId);
    if (order.status == status) return;

    final updates = {
      'status': status.toString().split('.').last,
      'updatedAt': DateTime.now(),
    };

    if (status == order_model.OrderStatus.delivered) {
      updates['deliveredAt'] = DateTime.now();
    } else if (status == order_model.OrderStatus.cancelled) {
      updates['cancelledAt'] = DateTime.now();
    }

    await _firestore.collection('orders').doc(orderId).update(updates);

    // Send notification
    await _notificationService.sendNotification(
      title: 'Order Status Updated',
      message:
          'Order #${order.id} status changed to ${status.toString().split('.').last}',
      type: notification.NotificationType.order,
      priority: notification.NotificationPriority.medium,
      data: order.copyWith(status: status).toMap(),
    );
  }

  Future<void> updateTrackingNumber(
    String orderId,
    String trackingNumber,
  ) async {
    final order = await fetchOrder(orderId);
    if (order.trackingNumber == trackingNumber) return;

    await _firestore.collection('orders').doc(orderId).update({
      'trackingNumber': trackingNumber,
      'updatedAt': DateTime.now(),
    });

    // Send notification
    await _notificationService.sendNotification(
      title: 'Tracking Number Updated',
      message: 'Order #${order.id} tracking number has been updated',
      type: notification.NotificationType.order,
      priority: notification.NotificationPriority.medium,
      data: order.copyWith(trackingNumber: trackingNumber).toMap(),
    );
  }

  Future<void> cancelOrder(String orderId) async {
    final order = await fetchOrder(orderId);
    if (order.status == order_model.OrderStatus.cancelled) return;

    await _firestore.collection('orders').doc(orderId).update({
      'status': order_model.OrderStatus.cancelled.toString().split('.').last,
      'cancelledAt': DateTime.now(),
      'updatedAt': DateTime.now(),
    });

    // Send notification
    await _notificationService.sendNotification(
      title: 'Order Cancelled',
      message: 'Order #${order.id} has been cancelled',
      type: notification.NotificationType.order,
      priority: notification.NotificationPriority.high,
      data: order.copyWith(status: order_model.OrderStatus.cancelled).toMap(),
    );
  }

  Future<Map<String, dynamic>> getOrderSummary() async {
    final snapshot = await _firestore
        .collection('orders')
        .where('vendorId', isEqualTo: _vendorId)
        .get();

    final orders = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return order_model.Order.fromMap({...data, 'id': doc.id});
    }).toList();

    Map<order_model.OrderStatus, int> statusCounts = {};
    double totalRevenue = 0;
    int totalOrders = orders.length;

    for (var order in orders) {
      statusCounts[order.status] = (statusCounts[order.status] ?? 0) + 1;
      if (order.status != order_model.OrderStatus.cancelled &&
          order.status != order_model.OrderStatus.refunded) {
        totalRevenue += order.total;
      }
    }

    return {
      'totalOrders': totalOrders,
      'totalRevenue': totalRevenue,
      'statusCounts': statusCounts,
    };
  }
}
