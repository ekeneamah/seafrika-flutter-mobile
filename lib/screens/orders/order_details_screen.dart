import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import '../../models/order.dart';
import '../../models/delivery_tracking.dart';
import '../../models/order_task.dart';
import '../../providers/service_providers.dart';

class OrderDetailsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> orderDetails;

  const OrderDetailsScreen({super.key, required this.orderDetails});

  @override
  ConsumerState<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends ConsumerState<OrderDetailsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Order get order => widget.orderDetails['order'] as Order;
  List<OrderTask> get tasks => widget.orderDetails['tasks'] as List<OrderTask>;
  DeliveryTracking? get delivery =>
      widget.orderDetails['delivery'] as DeliveryTracking?;
  OrderWorkflow? get workflow =>
      widget.orderDetails['workflow'] as OrderWorkflow?;
  List<dynamic> get activities =>
      widget.orderDetails['activities'] as List<dynamic>;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${order.id.substring(0, 8)}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'edit',
                child: Text('Edit Order'),
              ),
              const PopupMenuItem(
                value: 'share_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf),
                    SizedBox(width: 8),
                    Text('Share as PDF'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'share_payment',
                child: Row(
                  children: [
                    Icon(Icons.payment),
                    SizedBox(width: 8),
                    Text('Share Payment Info'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cancel',
                child: Text('Cancel Order'),
              ),
              const PopupMenuItem(
                value: 'refund',
                child: Text('Process Refund'),
              ),
              const PopupMenuItem(
                value: 'print',
                child: Text('Print Order'),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.info_outline)),
            Tab(text: 'Tasks', icon: Icon(Icons.task)),
            Tab(text: 'Tracking', icon: Icon(Icons.location_on)),
            Tab(text: 'Timeline', icon: Icon(Icons.timeline)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildTasksTab(),
          _buildTrackingTab(),
          _buildTimelineTab(),
        ],
      ),
      bottomNavigationBar: _buildBottomActions(),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildCustomerCard(),
          const SizedBox(height: 16),
          _buildOrderItemsCard(),
          const SizedBox(height: 16),
          _buildPaymentCard(),
          const SizedBox(height: 16),
          _buildShippingCard(),
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNotesCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order Status',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                _buildStatusChip(order.status),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text('Created: ${_formatDate(order.createdAt)}'),
              ],
            ),
            if (order.updatedAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.update, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text('Last Updated: ${_formatDate(order.updatedAt!)}'),
                ],
              ),
            ],
            if (order.deliveredAt != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Text('Delivered: ${_formatDate(order.deliveredAt!)}'),
                ],
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showStatusUpdateDialog(),
                child: const Text('Update Status'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person),
              title: Text(order.customerName),
              subtitle: Text('Customer ID: ${order.customerId}'),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: Text(order.customerEmail),
              onTap: () => _contactCustomer('email'),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: Text(order.customerPhone),
              onTap: () => _contactCustomer('phone'),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Order Items (${order.items.length})',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...order.items.map((item) => _buildOrderItem(item)),
            const Divider(),
            _buildOrderSummary(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[200],
            ),
            child: item.productImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item.productImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image),
                    ),
                  )
                : const Icon(Icons.image),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Qty: ${item.quantity} × \$${item.price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
          Text(
            '\$${item.total.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Column(
      children: [
        _buildSummaryRow('Subtotal', order.subtotal),
        _buildSummaryRow('Tax', order.tax),
        _buildSummaryRow('Shipping', order.shipping),
        const SizedBox(height: 8),
        _buildSummaryRow('Total', order.total, isTotal: true),
      ],
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 16 : 14,
                ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                  fontSize: isTotal ? 16 : 14,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.payment),
              title: Text('Payment Method'),
              subtitle: Text(order.paymentMethod),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.account_balance),
              title: Text('Payment Status'),
              subtitle: Text(order.paymentStatus),
              trailing: _buildPaymentStatusChip(order.paymentStatus),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShippingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shipping Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.location_on),
              title: const Text('Shipping Address'),
              subtitle: Text(order.shippingAddress),
              contentPadding: EdgeInsets.zero,
            ),
            if (order.trackingNumber != null) ...[
              ListTile(
                leading: const Icon(Icons.local_shipping),
                title: const Text('Tracking Number'),
                subtitle: Text(order.trackingNumber!),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () => _copyTrackingNumber(),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(order.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildTasksTab() {
    if (tasks.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.task, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No tasks assigned to this order'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _buildTaskCard(task);
      },
    );
  }

  Widget _buildTaskCard(OrderTask task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                _buildTaskStatusChip(task.status),
              ],
            ),
            const SizedBox(height: 8),
            Text(task.description),
            const SizedBox(height: 12),
            Row(
              children: [
                if (task.assignedToName != null) ...[
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text('Assigned to: ${task.assignedToName}'),
                  const SizedBox(width: 16),
                ],
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text('${task.estimatedDuration} min'),
              ],
            ),
            if (task.dueDate != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.event,
                    size: 16,
                    color: task.isOverdue ? Colors.red : Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Due: ${_formatDate(task.dueDate!)}',
                    style: TextStyle(
                      color: task.isOverdue ? Colors.red : null,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTaskActionButton(
                  'View Details',
                  Icons.visibility,
                  () => _viewTaskDetails(task),
                ),
                if (task.status != OrderTaskStatus.completed)
                  _buildTaskActionButton(
                    'Update Status',
                    Icons.update,
                    () => _updateTaskStatus(task),
                  ),
                _buildTaskActionButton(
                  'Add Comment',
                  Icons.comment,
                  () => _addTaskComment(task),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskActionButton(
      String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).primaryColor),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingTab() {
    if (delivery == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No delivery tracking available'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDeliveryInfoCard(),
          const SizedBox(height: 16),
          _buildDeliveryUpdatesCard(),
        ],
      ),
    );
  }

  Widget _buildDeliveryInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: Text('Tracking Number'),
              subtitle: Text(delivery!.trackingNumber),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text('Courier'),
              subtitle: Text(delivery!.courierName ?? 'Not assigned'),
              contentPadding: EdgeInsets.zero,
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text('Estimated Delivery'),
              subtitle: Text(_formatDate(delivery!.estimatedDelivery)),
              contentPadding: EdgeInsets.zero,
            ),
            if (delivery!.actualDelivery != null)
              ListTile(
                leading: const Icon(Icons.check_circle),
                title: Text('Actual Delivery'),
                subtitle: Text(_formatDate(delivery!.actualDelivery!)),
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryUpdatesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery Updates',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...delivery!.updates.map((update) => _buildDeliveryUpdate(update)),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryUpdate(DeliveryUpdate update) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  update.message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _formatDate(update.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    if (update.location != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.location_on,
                          size: 12, color: Colors.grey[600]),
                      const SizedBox(width: 2),
                      Text(
                        update.location!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _buildTimelineItem(activity);
      },
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> activity) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['action'] ?? 'Unknown Action',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                if (activity['description'] != null) ...[
                  const SizedBox(height: 4),
                  Text(activity['description']),
                ],
                const SizedBox(height: 4),
                Text(
                  'System • ${_formatDate((activity['timestamp'] as Timestamp).toDate())}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _contactCustomer,
              child: const Text('Contact Customer'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _getNextAction(),
              child: Text(_getNextActionText()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case OrderStatus.pending:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case OrderStatus.confirmed:
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case OrderStatus.processing:
        backgroundColor = Colors.yellow.shade100;
        textColor = Colors.yellow.shade800;
        break;
      case OrderStatus.shipped:
        backgroundColor = Colors.purple.shade100;
        textColor = Colors.purple.shade800;
        break;
      case OrderStatus.delivered:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case OrderStatus.cancelled:
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      case OrderStatus.refunded:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toString().split('.').last.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPaymentStatusChip(String paymentStatus) {
    Color backgroundColor;
    Color textColor;

    switch (paymentStatus.toLowerCase()) {
      case 'paid':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case 'pending':
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case 'failed':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        paymentStatus.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTaskStatusChip(OrderTaskStatus status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case OrderTaskStatus.pending:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade800;
        break;
      case OrderTaskStatus.assigned:
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        break;
      case OrderTaskStatus.in_progress:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        break;
      case OrderTaskStatus.completed:
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        break;
      case OrderTaskStatus.cancelled:
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
      case OrderTaskStatus.overdue:
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toString().split('.').last.toUpperCase(),
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  VoidCallback? _getNextAction() {
    switch (order.status) {
      case OrderStatus.pending:
        return () => _updateOrderStatus(OrderStatus.confirmed);
      case OrderStatus.confirmed:
        return () => _updateOrderStatus(OrderStatus.processing);
      case OrderStatus.processing:
        return () => _updateOrderStatus(OrderStatus.shipped);
      case OrderStatus.shipped:
        return () => _updateOrderStatus(OrderStatus.delivered);
      default:
        return null;
    }
  }

  String _getNextActionText() {
    switch (order.status) {
      case OrderStatus.pending:
        return 'Confirm Order';
      case OrderStatus.confirmed:
        return 'Start Processing';
      case OrderStatus.processing:
        return 'Mark as Shipped';
      case OrderStatus.shipped:
        return 'Mark as Delivered';
      default:
        return 'No Action';
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'edit':
        _editOrder();
        break;
      case 'share_pdf':
        _shareOrderAsPdf();
        break;
      case 'share_payment':
        _sharePaymentInfo();
        break;
      case 'cancel':
        _cancelOrder();
        break;
      case 'refund':
        _processRefund();
        break;
      case 'print':
        _printOrder();
        break;
    }
  }

  void _showStatusUpdateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: OrderStatus.values
              .map(
                (status) => RadioListTile<OrderStatus>(
                  title: Text(status.toString().split('.').last.toUpperCase()),
                  value: status,
                  groupValue: order.status,
                  onChanged: (value) {
                    Navigator.pop(context);
                    if (value != null) {
                      _updateOrderStatus(value);
                    }
                  },
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateOrderStatus(OrderStatus newStatus) async {
    try {
      final orderService = ref.read(orderManagementServiceProvider);
      await orderService.updateOrderStatus(order.id, newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Order status updated to ${newStatus.toString().split('.').last}'),
          ),
        );
        // Refresh the order details
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e')),
        );
      }
    }
  }

  void _contactCustomer([String? type]) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Call Customer'),
              onTap: () {
                Navigator.pop(context);
                // Implement phone call
              },
            ),
            ListTile(
              leading: const Icon(Icons.message),
              title: const Text('Send SMS'),
              onTap: () {
                Navigator.pop(context);
                // Implement SMS
              },
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: const Text('Send Email'),
              onTap: () {
                Navigator.pop(context);
                // Implement email
              },
            ),
          ],
        ),
      ),
    );
  }

  void _copyTrackingNumber() {
    // Implement copy to clipboard
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tracking number copied to clipboard')),
    );
  }

  void _viewTaskDetails(OrderTask task) {
    // Navigate to task details screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(task.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.description),
            const SizedBox(height: 16),
            Text('Type: ${task.type.toString().split('.').last}'),
            Text('Status: ${task.status.toString().split('.').last}'),
            Text('Priority: ${task.priority.toString().split('.').last}'),
            if (task.assignedToName != null)
              Text('Assigned to: ${task.assignedToName}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _updateTaskStatus(OrderTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Update Task Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: OrderTaskStatus.values
              .map(
                (status) => RadioListTile<OrderTaskStatus>(
                  title: Text(status.toString().split('.').last.toUpperCase()),
                  value: status,
                  groupValue: task.status,
                  onChanged: (value) {
                    Navigator.pop(context);
                    if (value != null) {
                      _performTaskStatusUpdate(task.id, value);
                    }
                  },
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _performTaskStatusUpdate(
      String taskId, OrderTaskStatus status) async {
    try {
      final orderService = ref.read(orderManagementServiceProvider);
      await orderService.updateTaskStatus(taskId, status);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Task status updated to ${status.toString().split('.').last}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating task status: $e')),
        );
      }
    }
  }

  void _addTaskComment(OrderTask task) {
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Comment'),
        content: TextField(
          controller: commentController,
          decoration: const InputDecoration(
            hintText: 'Enter your comment...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (commentController.text.isNotEmpty) {
                Navigator.pop(context);
                _performAddTaskComment(task.id, commentController.text);
              }
            },
            child: const Text('Add Comment'),
          ),
        ],
      ),
    );
  }

  Future<void> _performAddTaskComment(String taskId, String comment) async {
    try {
      final orderService = ref.read(orderManagementServiceProvider);
      final taskComment = OrderTaskComment(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: 'current_user_id', // Replace with actual user ID
        userName: 'Current User', // Replace with actual user name
        message: comment,
        createdAt: DateTime.now(),
        attachments: [],
      );

      await orderService.addTaskComment(taskId, taskComment);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comment added successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding comment: $e')),
        );
      }
    }
  }

  void _editOrder() {
    // Navigate to edit order screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit order feature not implemented yet')),
    );
  }

  void _cancelOrder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus(OrderStatus.cancelled);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _processRefund() {
    // Implementation for processing refund
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Refund processing not implemented yet')),
    );
  }

  void _printOrder() {
    // Implementation for printing order
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Print order feature not implemented yet')),
    );
  }

  Future<void> _sharePaymentInfo() async {
    try {
      // Generate payment information text
      final paymentText = _generatePaymentText();

      // Share the payment information
      await Share.share(
        paymentText,
        subject: 'Payment Instructions - Order #${order.id.substring(0, 8)}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment information shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing payment information: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generatePaymentText() {
    final buffer = StringBuffer();

    // Header
    buffer.writeln('💳 PAYMENT INSTRUCTIONS');
    buffer.writeln('Order #${order.id.substring(0, 8)}');
    buffer.writeln('Customer: ${order.customerName}');
    buffer.writeln('Total Amount: \$${order.total.toStringAsFixed(2)}');
    buffer.writeln('');

    // Payment status check
    if (order.paymentStatus.toLowerCase().contains('paid') ||
        order.paymentStatus.toLowerCase().contains('complete')) {
      buffer.writeln('✅ PAYMENT COMPLETED');
      buffer.writeln('This order has already been paid.');
      buffer.writeln('Payment Method: ${order.paymentMethod}');
    } else {
      buffer.writeln('💰 PAYMENT REQUIRED');
      buffer.writeln('Status: ${order.paymentStatus}');
      buffer.writeln('');

      // Bank transfer instructions
      buffer.writeln('📱 PAYMENT OPTIONS:');
      buffer.writeln('');
      buffer.writeln('1. BANK TRANSFER');
      buffer.writeln('   Account Name: [Your Business Name]');
      buffer.writeln('   Account Number: 1234567890');
      buffer.writeln('   Bank: First National Bank');
      buffer.writeln('   Reference: ORDER${order.id.substring(0, 8)}');
      buffer.writeln('');

      // Mobile money
      buffer.writeln('2. MOBILE MONEY');
      buffer.writeln('   M-Pesa: 0712345678');
      buffer.writeln('   Airtel Money: 0734567890');
      buffer.writeln('   Reference: ORDER${order.id.substring(0, 8)}');
      buffer.writeln('');

      // Online payment link (placeholder)
      buffer.writeln('3. ONLINE PAYMENT');
      buffer.writeln('   Pay securely online:');
      buffer.writeln(
          '   https://pay.yourbusiness.com/order/${order.id.substring(0, 8)}');
      buffer.writeln('');

      // Instructions
      buffer.writeln('📋 PAYMENT INSTRUCTIONS:');
      buffer.writeln('• Use the order reference for all payments');
      buffer.writeln('• Send payment confirmation after transfer');
      buffer.writeln('• Processing starts after payment verification');
      buffer.writeln('• Contact us for payment issues or queries');
    }

    buffer.writeln('');
    buffer.writeln('📞 CONTACT US:');
    buffer.writeln('Phone: +1 (555) 123-4567');
    buffer.writeln('Email: payments@yourbusiness.com');
    buffer.writeln('Support: Available 9 AM - 6 PM');

    buffer.writeln('');
    buffer.writeln('Thank you for your business! 🙏');

    return buffer.toString();
  }

  Future<void> _shareOrderAsPdf() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Generating PDF...'),
            ],
          ),
        ),
      );

      // Generate PDF document
      final pdf = await _generateOrderPdf();

      // Create a temporary PDF file
      final directory = await getTemporaryDirectory();
      final file =
          File('${directory.path}/order_${order.id.substring(0, 8)}.pdf');
      await file.writeAsBytes(await pdf.save());

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Share the PDF file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Order #${order.id.substring(0, 8)} - ${order.customerName}',
        text: 'Please find attached the order details.',
      );

      // Clean up the temporary file after sharing
      Future.delayed(const Duration(seconds: 10), () {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order PDF shared successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing order: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<pw.Document> _generateOrderPdf() async {
    final pdf = pw.Document();

    // Load fonts for better text rendering
    final fontData = await PdfGoogleFonts.nunitoRegular();
    final boldFontData = await PdfGoogleFonts.nunitoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            _buildPdfHeader(boldFontData, fontData),
            pw.SizedBox(height: 20),

            // Order Info
            _buildPdfOrderInfo(fontData, boldFontData),
            pw.SizedBox(height: 20),

            // Customer Info
            _buildPdfCustomerInfo(fontData, boldFontData),
            pw.SizedBox(height: 20),

            // Items Table
            _buildPdfItemsTable(fontData, boldFontData),
            pw.SizedBox(height: 20),

            // Order Summary
            _buildPdfOrderSummary(fontData, boldFontData),
            pw.SizedBox(height: 20),

            // Additional Info
            if (order.notes?.isNotEmpty == true)
              _buildPdfAdditionalInfo(fontData, boldFontData),

            // Tasks if any
            if (tasks.isNotEmpty) _buildPdfTasksSection(fontData, boldFontData),

            // Footer
            pw.Spacer(),
            _buildPdfFooter(fontData),
          ];
        },
      ),
    );

    return pdf;
  }

  pw.Widget _buildPdfHeader(pw.Font boldFont, pw.Font regularFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ORDER DETAILS',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Container(
          width: double.infinity,
          height: 2,
          color: PdfColors.blue800,
          margin: const pw.EdgeInsets.only(top: 8, bottom: 16),
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Order #${order.id.substring(0, 8)}',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 18,
                color: PdfColors.blue800,
              ),
            ),
            pw.Text(
              'Date: ${_formatDateTime(order.createdAt)}',
              style: pw.TextStyle(font: regularFont, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfOrderInfo(pw.Font regularFont, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'ORDER INFORMATION',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                        'Status:',
                        order.status.toString().split('.').last.toUpperCase(),
                        regularFont,
                        boldFont),
                    if (order.paymentMethod.isNotEmpty)
                      _buildInfoRow('Payment Method:', order.paymentMethod,
                          regularFont, boldFont),
                    if (order.paymentStatus.isNotEmpty)
                      _buildInfoRow('Payment Status:', order.paymentStatus,
                          regularFont, boldFont),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (order.trackingNumber?.isNotEmpty == true)
                      _buildInfoRow('Tracking Number:', order.trackingNumber!,
                          regularFont, boldFont),
                    _buildInfoRow('Created:', _formatDateTime(order.createdAt),
                        regularFont, boldFont),
                    if (order.updatedAt != null)
                      _buildInfoRow(
                          'Updated:',
                          _formatDateTime(order.updatedAt!),
                          regularFont,
                          boldFont),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfCustomerInfo(pw.Font regularFont, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CUSTOMER INFORMATION',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                        'Name:', order.customerName, regularFont, boldFont),
                    if (order.customerEmail.isNotEmpty)
                      _buildInfoRow(
                          'Email:', order.customerEmail, regularFont, boldFont),
                  ],
                ),
              ),
              pw.SizedBox(width: 20),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (order.customerPhone.isNotEmpty)
                      _buildInfoRow(
                          'Phone:', order.customerPhone, regularFont, boldFont),
                    if (order.shippingAddress.isNotEmpty)
                      _buildInfoRow('Address:', order.shippingAddress,
                          regularFont, boldFont),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfItemsTable(pw.Font regularFont, pw.Font boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'ORDER ITEMS',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('ITEM', boldFont, isHeader: true),
                _buildTableCell('QTY', boldFont, isHeader: true),
                _buildTableCell('PRICE', boldFont, isHeader: true),
                _buildTableCell('TOTAL', boldFont, isHeader: true),
              ],
            ),
            // Item rows
            ...order.items.map((item) {
              final itemTotal = item.price * item.quantity;
              return pw.TableRow(
                children: [
                  _buildTableCell(item.productName, regularFont),
                  _buildTableCell('${item.quantity}', regularFont),
                  _buildTableCell(
                      '\$${item.price.toStringAsFixed(2)}', regularFont),
                  _buildTableCell(
                      '\$${itemTotal.toStringAsFixed(2)}', regularFont),
                ],
              );
            }),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfOrderSummary(pw.Font regularFont, pw.Font boldFont) {
    return pw.Row(
      children: [
        pw.Expanded(flex: 2, child: pw.Container()),
        pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'ORDER SUMMARY',
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),
                _buildPdfSummaryRow('Subtotal:',
                    '\$${order.subtotal.toStringAsFixed(2)}', regularFont),
                if (order.tax > 0)
                  _buildPdfSummaryRow(
                      'Tax:', '\$${order.tax.toStringAsFixed(2)}', regularFont),
                if (order.shipping > 0)
                  _buildPdfSummaryRow('Shipping:',
                      '\$${order.shipping.toStringAsFixed(2)}', regularFont),
                pw.Divider(),
                _buildPdfSummaryRow(
                    'TOTAL:', '\$${order.total.toStringAsFixed(2)}', boldFont),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildPdfAdditionalInfo(pw.Font regularFont, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'SPECIAL INSTRUCTIONS',
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            order.notes!,
            style: pw.TextStyle(font: regularFont, fontSize: 12),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfTasksSection(pw.Font regularFont, pw.Font boldFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 20),
        pw.Text(
          'ORDER TASKS',
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        ...tasks.map((task) => pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 8),
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        task.title,
                        style: pw.TextStyle(font: boldFont, fontSize: 12),
                      ),
                      pw.Text(
                        task.status.toString().split('.').last.toUpperCase(),
                        style: pw.TextStyle(font: regularFont, fontSize: 10),
                      ),
                    ],
                  ),
                  if (task.assignedTo?.isNotEmpty == true) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Assigned to: ${task.assignedTo}',
                      style: pw.TextStyle(font: regularFont, fontSize: 10),
                    ),
                  ],
                  if (task.dueDate != null) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Due: ${_formatDateTime(task.dueDate!)}',
                      style: pw.TextStyle(font: regularFont, fontSize: 10),
                    ),
                  ],
                  if (task.description.isNotEmpty) ...[
                    pw.SizedBox(height: 4),
                    pw.Text(
                      task.description,
                      style: pw.TextStyle(font: regularFont, fontSize: 10),
                    ),
                  ],
                ],
              ),
            )),
      ],
    );
  }

  pw.Widget _buildPdfFooter(pw.Font regularFont) {
    return pw.Column(
      children: [
        pw.Container(
          width: double.infinity,
          height: 1,
          color: PdfColors.grey300,
          margin: const pw.EdgeInsets.symmetric(vertical: 16),
        ),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated on ${_formatDateTime(DateTime.now())}',
              style: pw.TextStyle(
                  font: regularFont, fontSize: 10, color: PdfColors.grey600),
            ),
            pw.Text(
              'Order #${order.id.substring(0, 8)}',
              style: pw.TextStyle(
                  font: regularFont, fontSize: 10, color: PdfColors.grey600),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildInfoRow(
      String label, String value, pw.Font regularFont, pw.Font boldFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              label,
              style: pw.TextStyle(font: boldFont, fontSize: 10),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(font: regularFont, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTableCell(String text, pw.Font font,
      {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _buildPdfSummaryRow(String label, String value, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(font: font, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
