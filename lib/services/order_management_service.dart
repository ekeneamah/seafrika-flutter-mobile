import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/delivery_tracking.dart';
import '../models/order_task.dart';
import '../config/collection_references.dart';

/// Exception types for order management operations
class OrderManagementException implements Exception {
  final String message;
  final String code;

  const OrderManagementException(this.message, this.code);

  @override
  String toString() => 'OrderManagementException: $message (Code: $code)';
}

class OrderManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _vendorId;

  OrderManagementService({required String vendorId}) : _vendorId = vendorId;

  // MARK: - Order Management

  /// Create a new order with automatic workflow setup (flat architecture)
  Future<String> createOrder(Order order) async {
    try {
      final batch = _firestore.batch();

      // Create order document in flat collection structure
      final orderRef = CollectionReferences.orders.doc(order.id);

      // Ensure order has vendorId and businessId for proper filtering
      final orderData = {
        ...order.toMap(),
        'vendorId': _vendorId,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      batch.set(orderRef, orderData);

      // Create default workflow for the order (can be kept in nested structure for workflows)
      final workflow = await _createDefaultWorkflow(order.id);
      final workflowRef = _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('order_workflows')
          .doc(workflow.id);

      batch.set(workflowRef, workflow.toMap());

      // Create initial tasks based on workflow
      for (int i = 0; i < workflow.steps.length; i++) {
        final step = workflow.steps[i];
        final task = _createTaskFromWorkflowStep(order.id, step, i == 0);

        final taskRef = _firestore
            .collection('vendors')
            .doc(_vendorId)
            .collection('order_tasks')
            .doc(task.id);

        batch.set(taskRef, task.toMap());
      }

      await batch.commit();

      // Log activity
      await _logOrderActivity(
        order.id,
        'Order created',
        'New order created with ${order.items.length} items',
      );

      return order.id;
    } catch (e) {
      debugPrint('Create order error: $e');
      throw OrderManagementException(
        'Failed to create order: $e',
        'CREATE_ORDER_ERROR',
      );
    }
  }

  /// Update order status with automatic workflow progression
  Future<void> updateOrderStatus(String orderId, OrderStatus newStatus) async {
    try {
      final batch = _firestore.batch();

      // Update order
      final orderRef = _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('orders')
          .doc(orderId);

      final updateData = {
        'status': newStatus.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add completion timestamp if delivered
      if (newStatus == OrderStatus.delivered) {
        updateData['deliveredAt'] = FieldValue.serverTimestamp();
      } else if (newStatus == OrderStatus.cancelled) {
        updateData['cancelledAt'] = FieldValue.serverTimestamp();
      }

      batch.update(orderRef, updateData);

      // Update workflow based on status
      await _updateWorkflowForStatus(orderId, newStatus);

      await batch.commit();

      // Log activity
      await _logOrderActivity(
        orderId,
        'Status updated',
        'Order status changed to ${newStatus.toString().split('.').last}',
      );
    } catch (e) {
      debugPrint('Update order status error: $e');
      throw OrderManagementException(
        'Failed to update order status: $e',
        'UPDATE_STATUS_ERROR',
      );
    }
  }

  /// Get order with all related data
  Future<Map<String, dynamic>> getOrderDetails(String orderId) async {
    try {
      final futures = await Future.wait([
        _getOrder(orderId),
        _getOrderTasks(orderId),
        _getDeliveryTracking(orderId),
        _getOrderWorkflow(orderId),
        _getOrderActivities(orderId),
      ]);

      return {
        'order': futures[0],
        'tasks': futures[1],
        'delivery': futures[2],
        'workflow': futures[3],
        'activities': futures[4],
      };
    } catch (e) {
      debugPrint('Get order details error: $e');
      throw OrderManagementException(
        'Failed to get order details: $e',
        'GET_ORDER_ERROR',
      );
    }
  }

  /// Get orders with filtering and pagination (optimized for flat architecture)
  Future<List<Order>> getOrders({
    String? businessId,
    OrderStatus? status,
    DateTime? fromDate,
    DateTime? toDate,
    int limit = 20,
    DocumentSnapshot? lastDocument,
  }) async {
    try {
      Query query;

      // Use flat collection structure with business filtering
      if (businessId != null) {
        // Use optimized collection reference for business orders
        query = CollectionReferences.ordersForBusiness(businessId);

        // Apply additional filters
        if (status != null) {
          // Use composite index for better performance
          query = query
              .where('status', isEqualTo: status.toString().split('.').last)
              .orderBy('createdAt', descending: true);
        } else {
          query = query.orderBy('createdAt', descending: true);
        }
      } else {
        // Fallback: get all orders for vendor (less efficient, avoid if possible)
        query = CollectionReferences.orders
            .where('vendorId', isEqualTo: _vendorId)
            .orderBy('createdAt', descending: true);

        if (status != null) {
          query = query.where('status',
              isEqualTo: status.toString().split('.').last);
        }
      }

      // Date range filtering (be careful with compound queries)
      if (fromDate != null && toDate != null) {
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: fromDate)
            .where('createdAt', isLessThanOrEqualTo: toDate);
      } else if (fromDate != null) {
        query = query.where('createdAt', isGreaterThanOrEqualTo: fromDate);
      }

      // Pagination
      if (lastDocument != null) {
        query = query.startAfterDocument(lastDocument);
      }

      // Limit to control read costs
      query = query.limit(limit);

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => Order.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Get orders error: $e');
      throw OrderManagementException(
        'Failed to get orders: $e',
        'GET_ORDERS_ERROR',
      );
    }
  }

  /// Get pending orders for a business (optimized query)
  Future<List<Order>> getPendingOrders(String businessId,
      {int limit = 10}) async {
    try {
      final snapshot = await CollectionReferences.pendingOrders(businessId)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Order.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Get pending orders error: $e');
      throw OrderManagementException(
        'Failed to get pending orders: $e',
        'GET_PENDING_ORDERS_ERROR',
      );
    }
  }

  /// Get orders by date range (optimized for analytics)
  Future<List<Order>> getOrdersByDateRange(
    String businessId,
    DateTime startDate,
    DateTime endDate, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await CollectionReferences.ordersByDateRange(
              businessId, startDate, endDate)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => Order.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Get orders by date range error: $e');
      throw OrderManagementException(
        'Failed to get orders by date range: $e',
        'GET_ORDERS_DATE_RANGE_ERROR',
      );
    }
  }

  // MARK: - Delivery Tracking

  /// Create delivery tracking for an order
  Future<String> createDeliveryTracking(DeliveryTracking tracking) async {
    try {
      final docRef = _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('delivery_tracking')
          .doc(tracking.id);

      await docRef.set(tracking.toMap());

      // Update order with tracking number
      await _updateOrderTrackingNumber(
          tracking.orderId, tracking.trackingNumber);

      // Log initial delivery update
      await _addDeliveryUpdate(
        tracking.id,
        'Order prepared for shipment',
        'Package is ready for pickup',
        null,
      );

      return tracking.id;
    } catch (e) {
      debugPrint('Create delivery tracking error: $e');
      throw OrderManagementException(
        'Failed to create delivery tracking: $e',
        'CREATE_DELIVERY_ERROR',
      );
    }
  }

  /// Update delivery status with location
  Future<void> updateDeliveryStatus(
    String trackingId,
    DeliveryStatus status,
    String message, {
    String? location,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final batch = _firestore.batch();

      // Update delivery tracking
      final trackingRef = _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('delivery_tracking')
          .doc(trackingId);

      final updateData = {
        'status': status.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (latitude != null && longitude != null) {
        updateData['latitude'] = latitude;
        updateData['longitude'] = longitude;
      }

      if (status == DeliveryStatus.delivered) {
        updateData['actualDelivery'] = FieldValue.serverTimestamp();
      }

      batch.update(trackingRef, updateData);

      // Add delivery update
      final update = DeliveryUpdate(
        status: status.toString().split('.').last,
        message: message,
        location: location,
        timestamp: DateTime.now(),
      );

      batch.update(trackingRef, {
        'updates': FieldValue.arrayUnion([update.toMap()])
      });

      await batch.commit();

      // If delivered, update order status
      if (status == DeliveryStatus.delivered) {
        final trackingDoc = await trackingRef.get();
        if (trackingDoc.exists) {
          final tracking = DeliveryTracking.fromMap(trackingDoc.data()!);
          await updateOrderStatus(tracking.orderId, OrderStatus.delivered);
        }
      }
    } catch (e) {
      debugPrint('Update delivery status error: $e');
      throw OrderManagementException(
        'Failed to update delivery status: $e',
        'UPDATE_DELIVERY_ERROR',
      );
    }
  }

  /// Get delivery tracking by order ID
  Future<DeliveryTracking?> getDeliveryTrackingByOrderId(String orderId) async {
    try {
      final snapshot = await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('delivery_tracking')
          .where('orderId', isEqualTo: orderId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return DeliveryTracking.fromMap(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      debugPrint('Get delivery tracking error: $e');
      throw OrderManagementException(
        'Failed to get delivery tracking: $e',
        'GET_DELIVERY_ERROR',
      );
    }
  }

  // MARK: - Task Management

  /// Create a new order task
  Future<String> createOrderTask(OrderTask task) async {
    try {
      final docRef = _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('order_tasks')
          .doc(task.id);

      await docRef.set(task.toMap());

      // Log activity
      await _logOrderActivity(
        task.orderId,
        'Task created',
        'New ${task.type.toString().split('.').last} task: ${task.title}',
      );

      return task.id;
    } catch (e) {
      debugPrint('Create order task error: $e');
      throw OrderManagementException(
        'Failed to create order task: $e',
        'CREATE_TASK_ERROR',
      );
    }
  }

  /// Assign task to a team member
  Future<void> assignTask(String taskId, String userId, String userName) async {
    try {
      final taskRef = _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('order_tasks')
          .doc(taskId);

      await taskRef.update({
        'assignedTo': userId,
        'assignedToName': userName,
        'status': OrderTaskStatus.assigned.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Get task to log activity
      final taskDoc = await taskRef.get();
      if (taskDoc.exists) {
        final task = OrderTask.fromMap(taskDoc.data()!);
        await _logOrderActivity(
          task.orderId,
          'Task assigned',
          'Task "${task.title}" assigned to $userName',
        );
      }
    } catch (e) {
      debugPrint('Assign task error: $e');
      throw OrderManagementException(
        'Failed to assign task: $e',
        'ASSIGN_TASK_ERROR',
      );
    }
  }

  /// Update task status
  Future<void> updateTaskStatus(String taskId, OrderTaskStatus status) async {
    try {
      final taskRef = _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('order_tasks')
          .doc(taskId);

      final updateData = {
        'status': status.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == OrderTaskStatus.in_progress) {
        updateData['startedAt'] = FieldValue.serverTimestamp();
      } else if (status == OrderTaskStatus.completed) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }

      await taskRef.update(updateData);

      // Get task to update workflow and log activity
      final taskDoc = await taskRef.get();
      if (taskDoc.exists) {
        final task = OrderTask.fromMap(taskDoc.data()!);

        // Update workflow if task completed
        if (status == OrderTaskStatus.completed) {
          await _progressWorkflow(task.orderId, task.type);
        }

        await _logOrderActivity(
          task.orderId,
          'Task updated',
          'Task "${task.title}" status: ${status.toString().split('.').last}',
        );
      }
    } catch (e) {
      debugPrint('Update task status error: $e');
      throw OrderManagementException(
        'Failed to update task status: $e',
        'UPDATE_TASK_ERROR',
      );
    }
  }

  /// Get tasks for an order
  Future<List<OrderTask>> getOrderTasks(String orderId) async {
    try {
      final snapshot = await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('order_tasks')
          .where('orderId', isEqualTo: orderId)
          .orderBy('createdAt')
          .get();

      return snapshot.docs.map((doc) => OrderTask.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Get order tasks error: $e');
      throw OrderManagementException(
        'Failed to get order tasks: $e',
        'GET_TASKS_ERROR',
      );
    }
  }

  /// Get tasks assigned to a specific user
  Future<List<OrderTask>> getAssignedTasks(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('order_tasks')
          .where('assignedTo', isEqualTo: userId)
          .where('status', whereIn: [
            OrderTaskStatus.assigned.toString().split('.').last,
            OrderTaskStatus.in_progress.toString().split('.').last,
          ])
          .orderBy('dueDate')
          .get();

      return snapshot.docs.map((doc) => OrderTask.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Get assigned tasks error: $e');
      throw OrderManagementException(
        'Failed to get assigned tasks: $e',
        'GET_ASSIGNED_TASKS_ERROR',
      );
    }
  }

  /// Add comment to a task
  Future<void> addTaskComment(String taskId, OrderTaskComment comment) async {
    try {
      final taskRef = _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('order_tasks')
          .doc(taskId);

      await taskRef.update({
        'comments': FieldValue.arrayUnion([comment.toMap()]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Add task comment error: $e');
      throw OrderManagementException(
        'Failed to add task comment: $e',
        'ADD_COMMENT_ERROR',
      );
    }
  }

  // MARK: - Analytics and Reporting

  /// Get order analytics for a date range
  Future<Map<String, dynamic>> getOrderAnalytics({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    try {
      final from =
          fromDate ?? DateTime.now().subtract(const Duration(days: 30));
      final to = toDate ?? DateTime.now();

      final ordersQuery = _firestore
          .collection('vendors')
          .doc(_vendorId)
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: from)
          .where('createdAt', isLessThanOrEqualTo: to);

      final snapshot = await ordersQuery.get();
      final orders =
          snapshot.docs.map((doc) => Order.fromMap(doc.data())).toList();

      // Calculate analytics
      final analytics = _calculateOrderAnalytics(orders);

      return analytics;
    } catch (e) {
      debugPrint('Get order analytics error: $e');
      throw OrderManagementException(
        'Failed to get order analytics: $e',
        'GET_ANALYTICS_ERROR',
      );
    }
  }

  // MARK: - Private Helper Methods

  Future<Order?> _getOrder(String orderId) async {
    // Use flat collection structure
    final doc = await CollectionReferences.orders.doc(orderId).get();

    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data != null) {
        // Ensure the order belongs to this vendor for security
        if (data['vendorId'] == _vendorId) {
          return Order.fromMap(data);
        }
      }
    }
    return null;
  }

  Future<List<OrderTask>> _getOrderTasks(String orderId) async {
    final snapshot = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('order_tasks')
        .where('orderId', isEqualTo: orderId)
        .get();

    return snapshot.docs.map((doc) => OrderTask.fromMap(doc.data())).toList();
  }

  Future<DeliveryTracking?> _getDeliveryTracking(String orderId) async {
    final snapshot = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('delivery_tracking')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return DeliveryTracking.fromMap(snapshot.docs.first.data());
    }
    return null;
  }

  Future<OrderWorkflow?> _getOrderWorkflow(String orderId) async {
    final snapshot = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('order_workflows')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return OrderWorkflow.fromMap(snapshot.docs.first.data());
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> _getOrderActivities(String orderId) async {
    final snapshot = await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('order_activities')
        .where('orderId', isEqualTo: orderId)
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<OrderWorkflow> _createDefaultWorkflow(String orderId) async {
    final steps = [
      WorkflowStep(
        id: '1',
        name: 'Order Confirmation',
        description: 'Confirm order details and payment',
        taskType: OrderTaskType.preparation,
        isRequired: true,
        isCompleted: false,
      ),
      WorkflowStep(
        id: '2',
        name: 'Preparation',
        description: 'Prepare items for packing',
        taskType: OrderTaskType.preparation,
        isRequired: true,
        isCompleted: false,
      ),
      WorkflowStep(
        id: '3',
        name: 'Quality Check',
        description: 'Verify items quality and completeness',
        taskType: OrderTaskType.quality_check,
        isRequired: true,
        isCompleted: false,
      ),
      WorkflowStep(
        id: '4',
        name: 'Packing',
        description: 'Pack items securely for shipping',
        taskType: OrderTaskType.packing,
        isRequired: true,
        isCompleted: false,
      ),
      WorkflowStep(
        id: '5',
        name: 'Shipping',
        description: 'Hand over to shipping partner',
        taskType: OrderTaskType.shipping,
        isRequired: true,
        isCompleted: false,
      ),
    ];

    return OrderWorkflow(
      id: 'wf_${orderId}_${DateTime.now().millisecondsSinceEpoch}',
      orderId: orderId,
      vendorId: _vendorId,
      steps: steps,
      currentStepIndex: 0,
      status: WorkflowStatus.active,
      createdAt: DateTime.now(),
    );
  }

  OrderTask _createTaskFromWorkflowStep(
      String orderId, WorkflowStep step, bool isActive) {
    return OrderTask(
      id: 'task_${orderId}_${step.id}_${DateTime.now().millisecondsSinceEpoch}',
      orderId: orderId,
      vendorId: _vendorId,
      type: step.taskType,
      title: step.name,
      description: step.description,
      status: isActive ? OrderTaskStatus.pending : OrderTaskStatus.pending,
      priority: OrderTaskPriority.medium,
      estimatedDuration: _getEstimatedDurationForTaskType(step.taskType),
      attachments: [],
      comments: [],
      createdAt: DateTime.now(),
    );
  }

  int _getEstimatedDurationForTaskType(OrderTaskType type) {
    switch (type) {
      case OrderTaskType.preparation:
        return 60; // 1 hour
      case OrderTaskType.quality_check:
        return 30; // 30 minutes
      case OrderTaskType.packing:
        return 45; // 45 minutes
      case OrderTaskType.shipping:
        return 15; // 15 minutes
      case OrderTaskType.delivery:
        return 120; // 2 hours
      case OrderTaskType.customer_service:
        return 30; // 30 minutes
      default:
        return 60; // 1 hour default
    }
  }

  Future<void> _updateWorkflowForStatus(
      String orderId, OrderStatus status) async {
    // Implementation for updating workflow based on order status
    // This would progress the workflow to appropriate steps
  }

  Future<void> _progressWorkflow(String orderId, OrderTaskType taskType) async {
    // Implementation for progressing workflow when tasks complete
  }

  Future<void> _updateOrderTrackingNumber(
      String orderId, String trackingNumber) async {
    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('orders')
        .doc(orderId)
        .update({
      'trackingNumber': trackingNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _addDeliveryUpdate(
    String trackingId,
    String message,
    String status,
    String? location,
  ) async {
    final update = DeliveryUpdate(
      status: status,
      message: message,
      location: location,
      timestamp: DateTime.now(),
    );

    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('delivery_tracking')
        .doc(trackingId)
        .update({
      'updates': FieldValue.arrayUnion([update.toMap()])
    });
  }

  Future<void> _logOrderActivity(
    String orderId,
    String action,
    String description,
  ) async {
    await _firestore
        .collection('vendors')
        .doc(_vendorId)
        .collection('order_activities')
        .add({
      'orderId': orderId,
      'action': action,
      'description': description,
      'timestamp': FieldValue.serverTimestamp(),
      'userId': 'system', // Replace with actual user ID
    });
  }

  Map<String, dynamic> _calculateOrderAnalytics(List<Order> orders) {
    final totalOrders = orders.length;
    final totalRevenue =
        orders.fold<double>(0, (sum, order) => sum + order.total);
    final averageOrderValue =
        totalOrders > 0 ? totalRevenue / totalOrders : 0.0;

    final statusCounts = <String, int>{};
    for (final order in orders) {
      final status = order.status.toString().split('.').last;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return {
      'totalOrders': totalOrders,
      'totalRevenue': totalRevenue,
      'averageOrderValue': averageOrderValue,
      'statusCounts': statusCounts,
      'completionRate': totalOrders > 0
          ? (statusCounts['delivered'] ?? 0) / totalOrders
          : 0.0,
    };
  }
}
