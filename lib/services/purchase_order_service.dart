import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/models/purchase_order.dart';
import 'package:vendor_app/services/notification_service.dart';

class PurchaseOrderService {
  final FirebaseFirestore _firestore;
  final String _vendorId;
  final NotificationService _notificationService;

  PurchaseOrderService(
      this._firestore, this._vendorId, this._notificationService);

  // Purchase Order Management
  Stream<List<PurchaseOrder>> streamPurchaseOrders({
    String? supplierId,
    PurchaseOrderStatus? status,
    String? searchQuery,
    DocumentSnapshot? lastDocument,
    int? limit,
  }) {
    Query query = _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('purchase_orders')
        .orderBy('createdAt', descending: true);

    if (supplierId != null) {
      query = query.where('supplierId', isEqualTo: supplierId);
    }
    if (status != null) {
      query =
          query.where('status', isEqualTo: status.toString().split('.').last);
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    if (limit != null) {
      query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      final orders = snapshot.docs
          .map((doc) => PurchaseOrder.fromMap(
              {...(doc.data() as Map<String, dynamic>? ?? {}), 'id': doc.id}))
          .toList();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        return orders.where((order) {
          return order.orderNumber.toLowerCase().contains(query) ||
              order.supplierName.toLowerCase().contains(query) ||
              order.items.any(
                  (item) => item.productName.toLowerCase().contains(query));
        }).toList();
      }

      return orders;
    });
  }

  Future<PurchaseOrder> fetchPurchaseOrder(String orderId) async {
    final doc = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('purchase_orders')
        .doc(orderId)
        .get();

    if (!doc.exists) {
      throw Exception('Purchase order not found');
    }

    return PurchaseOrder.fromMap({...doc.data()!, 'id': doc.id});
  }

  Future<PurchaseOrder> createPurchaseOrder({
    required String supplierId,
    required String supplierName,
    required List<PurchaseOrderItem> items,
    required double totalAmount,
    DateTime? expectedDeliveryDate,
    String? notes,
    String? createdBy,
  }) async {
    final docRef = _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('purchase_orders')
        .doc();

    final orderNumber = await _generateOrderNumber();

    final order = PurchaseOrder(
      id: docRef.id,
      vendorId: _vendorId,
      supplierId: supplierId,
      supplierName: supplierName,
      orderNumber: orderNumber,
      items: items,
      totalAmount: totalAmount,
      status: PurchaseOrderStatus.draft,
      expectedDeliveryDate: expectedDeliveryDate,
      notes: notes,
      createdBy: createdBy,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(order.toMap());

    // Send notification
    await _notificationService.sendNotification(
      title: 'New Purchase Order Created',
      message: 'Order #$orderNumber',
      data: {
        'type': 'purchase_order',
        'orderId': order.id,
      },
    );

    return order;
  }

  Future<void> updatePurchaseOrder(
    String orderId, {
    String? supplierId,
    String? supplierName,
    List<PurchaseOrderItem>? items,
    double? totalAmount,
    DateTime? expectedDeliveryDate,
    String? notes,
  }) async {
    final updates = <String, dynamic>{
      'updatedAt': DateTime.now(),
    };

    if (supplierId != null) {
      updates['supplierId'] = supplierId;
    }
    if (supplierName != null) {
      updates['supplierName'] = supplierName;
    }
    if (items != null) {
      updates['items'] = items.map((item) => item.toMap()).toList();
    }
    if (totalAmount != null) {
      updates['totalAmount'] = totalAmount;
    }
    if (expectedDeliveryDate != null) {
      updates['expectedDeliveryDate'] =
          Timestamp.fromDate(expectedDeliveryDate);
    }
    if (notes != null) {
      updates['notes'] = notes;
    }

    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('purchase_orders')
        .doc(orderId)
        .update(updates);
  }

  Future<void> updatePurchaseOrderStatus(
    String orderId,
    PurchaseOrderStatus status, {
    String? approvedBy,
  }) async {
    final updates = {
      'status': status.toString().split('.').last,
      'updatedAt': DateTime.now(),
    };

    if (approvedBy != null) {
      updates['approvedBy'] = approvedBy;
    }

    if (status == PurchaseOrderStatus.delivered) {
      updates['actualDeliveryDate'] = DateTime.now();
    }

    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('purchase_orders')
        .doc(orderId)
        .update(updates);

    // Send notification for status change
    final order = await fetchPurchaseOrder(orderId);
    await _notificationService.sendNotification(
      title: 'Purchase Order Status Updated',
      message:
          'Order #${order.orderNumber} - ${status.toString().split('.').last}',
      data: {
        'type': 'purchase_order_status',
        'orderId': order.id,
      },
    );
  }

  Future<void> deletePurchaseOrder(String orderId) async {
    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('purchase_orders')
        .doc(orderId)
        .delete();
  }

  // Analytics
  Future<Map<String, dynamic>> getPurchaseOrderSummary() async {
    final snapshot = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('purchase_orders')
        .get();

    final orders = snapshot.docs
        .map((doc) => PurchaseOrder.fromMap(
            {...(doc.data() as Map<String, dynamic>? ?? {}), 'id': doc.id}))
        .toList();

    Map<String, int> supplierCounts = {};
    Map<PurchaseOrderStatus, int> statusCounts = {};
    double totalAmount = 0;
    int totalOrders = orders.length;

    for (var order in orders) {
      supplierCounts[order.supplierName] =
          (supplierCounts[order.supplierName] ?? 0) + 1;
      statusCounts[order.status] = (statusCounts[order.status] ?? 0) + 1;
      totalAmount += order.totalAmount;
    }

    return {
      'totalOrders': totalOrders,
      'totalAmount': totalAmount,
      'supplierCounts': supplierCounts,
      'statusCounts': statusCounts,
    };
  }

  // Helper Methods
  Future<String> _generateOrderNumber() async {
    final year = DateTime.now().year.toString().substring(2);
    final month = DateTime.now().month.toString().padLeft(2, '0');

    final snapshot = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('purchase_orders')
        .where('orderNumber', isGreaterThanOrEqualTo: 'PO$year$month')
        .where('orderNumber', isLessThan: 'PO$year${int.parse(month) + 1}')
        .orderBy('orderNumber', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return 'PO$year${month}0001';
    }

    final lastOrderNumber = snapshot.docs.first.data()['orderNumber'] as String;
    final lastNumber = int.parse(lastOrderNumber.substring(6));
    return 'PO$year$month${(lastNumber + 1).toString().padLeft(4, '0')}';
  }
}
