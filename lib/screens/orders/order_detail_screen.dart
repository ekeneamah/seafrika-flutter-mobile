import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/order.dart';
import 'package:vendor_app/models/task.dart';
import 'package:vendor_app/models/user.dart';
import 'package:vendor_app/models/booking.dart';
import 'package:vendor_app/models/notification.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/order_service.dart';
import 'package:vendor_app/services/task_service.dart';
import 'package:vendor_app/services/user_service.dart';
import 'package:vendor_app/services/notification_service.dart';
import 'package:vendor_app/services/auth_service.dart';
import 'package:vendor_app/services/booking_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:intl/intl.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  bool _isLoading = false;
  String? _error;
  Order? _order;
  final _messageController = TextEditingController();
  String? _selectedAssignee;
  String? _selectedTeam;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final order =
          await context.read<OrderService>().fetchOrder(widget.orderId);
      setState(() {
        _order = order;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showStatusUpdateDialog() {
    if (_order == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Order Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: OrderStatus.values.map((status) {
            return ListTile(
              title: Text(status.toString().split('.').last),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await context.read<OrderService>().updateOrderStatus(
                        _order!.id,
                        status,
                      );
                  await _loadOrder();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Order status updated')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: ${e.toString()}')),
                    );
                  }
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showMessageDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Message to Customer'),
        content: TextField(
          controller: _messageController,
          decoration: const InputDecoration(
            labelText: 'Message',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_messageController.text.isEmpty) return;
              Navigator.pop(context);
              try {
                await context.read<NotificationService>().sendNotification(
                  title: 'Message from Vendor',
                  message: _messageController.text,
                  type: NotificationType.message,
                  priority: NotificationPriority.medium,
                  data: {
                    'type': 'order_message',
                    'orderId': _order!.id,
                  },
                );
                _messageController.clear();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message sent')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')),
                  );
                }
              }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showCreateTaskDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Task from Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StreamBuilder<List<User>>(
              stream: context.read<UserService>().streamUsers(isActive: true),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                final users = snapshot.data!;
                return Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedAssignee,
                      decoration: const InputDecoration(
                        labelText: 'Assign To',
                        border: OutlineInputBorder(),
                      ),
                      items: users.map((user) {
                        return DropdownMenuItem(
                          value: user.id,
                          child: Text(user.fullName),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedAssignee = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            if (_selectedAssignee == null) return;
                            Navigator.pop(context);
                            try {
                              final assignedToUser = users
                                  .firstWhere((u) => u.id == _selectedAssignee);
                              final assignedToName = assignedToUser.fullName;
                              final userName = context
                                      .read<AuthService>()
                                      .currentUser
                                      ?.fullName ??
                                  '';
                              final task = Task(
                                id: '',
                                title: 'Process Order #${_order!.id}',
                                description:
                                    'Customer: ${_order!.customerName}\n'
                                    'Total: \$${_order!.total.toStringAsFixed(2)}\n'
                                    'Items: ${_order!.items.length}',
                                type: TaskType.general,
                                priority: TaskPriority.medium,
                                status: TaskStatus.pending,
                                dueDate:
                                    DateTime.now().add(const Duration(days: 1)),
                                assignedTo: _selectedAssignee!,
                                assignedBy: context
                                        .read<AuthService>()
                                        .currentUser
                                        ?.id ??
                                    '',
                                createdAt: DateTime.now(),
                                relatedItemId: _order!.id,
                                comments: [],
                                activities: [],
                              );

                              await context.read<TaskService>().createTask(
                                    task,
                                    userName: userName,
                                    assignedToName: assignedToName,
                                  );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Task created')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text('Error: \\${e.toString()}')),
                                );
                              }
                            }
                          },
                          child: const Text('Create Task'),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _createBooking() async {
    if (_order == null) return;

    try {
      final bookingService = context.read<BookingService>();
      final booking = await bookingService.createBooking(
        customerId: _order!.customerId,
        customerName: _order!.customerName,
        customerEmail: _order!.customerEmail,
        customerPhone: _order!.customerPhone,
        bookingDate: DateTime.now(),
        items: _order!.items
            .map((item) => BookingItem(
                  inventoryId: item.productId,
                  productName: item.productName,
                  quantity: item.quantity,
                  unitPrice: item.price,
                ))
            .toList(),
        notes: 'Created from order #${_order!.id}',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking created successfully')),
        );
        NavigationService.navigateToBookingDetail(booking.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating booking: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingView();
    }

    if (_error != null) {
      return error.ErrorView(
        message: _error!,
        onRetry: _loadOrder,
      );
    }

    if (_order == null) {
      return const Scaffold(
        body: Center(
          child: Text('Order not found'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${_order!.id}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showStatusUpdateDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order Status: ${_order!.status.toString().split('.').last}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Customer Information',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Name: ${_order!.customerName}'),
                    Text('Email: ${_order!.customerEmail}'),
                    Text('Phone: ${_order!.customerPhone}'),
                    Text('Address: ${_order!.shippingAddress}'),
                    const Divider(),
                    Text(
                      'Order Items',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ..._order!.items.map((item) => ListTile(
                          title: Text(item.productName),
                          subtitle: Text(
                              'Quantity: ${item.quantity} x \$${item.price.toStringAsFixed(2)}'),
                          trailing: Text('\$${item.total.toStringAsFixed(2)}'),
                        )),
                    const Divider(),
                    Text(
                      'Payment Information',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text('Method: ${_order!.paymentMethod}'),
                    Text('Status: ${_order!.paymentStatus}'),
                    Text('Subtotal: \$${_order!.subtotal.toStringAsFixed(2)}'),
                    Text('Tax: \$${_order!.tax.toStringAsFixed(2)}'),
                    Text('Shipping: \$${_order!.shipping.toStringAsFixed(2)}'),
                    Text(
                      'Total: \$${_order!.total.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_order!.trackingNumber != null) ...[
                      const Divider(),
                      Text(
                        'Shipping Information',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text('Tracking Number: ${_order!.trackingNumber}'),
                    ],
                    if (_order!.notes != null) ...[
                      const Divider(),
                      Text(
                        'Notes',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(_order!.notes!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _showMessageDialog,
                  icon: const Icon(Icons.message),
                  label: const Text('Message Customer'),
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateTaskDialog,
                  icon: const Icon(Icons.task),
                  label: const Text('Create Task'),
                ),
                ElevatedButton.icon(
                  onPressed: _createBooking,
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Create Booking'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
