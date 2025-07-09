import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/order.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/order_service.dart';
import 'package:vendor_app/services/auth_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:intl/intl.dart';

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  final _searchController = TextEditingController();
  OrderStatus? _selectedStatus;
  String _searchQuery = '';
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Orders are loaded through StreamBuilder
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Orders'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<OrderStatus>(
              value: _selectedStatus,
              decoration: const InputDecoration(labelText: 'Status'),
              items: OrderStatus.values.map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(status.toString().split('.').last),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedStatus = value);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _selectedStatus = null;
              });
              Navigator.pop(context);
            },
            child: const Text('Clear Filter'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStatusUpdateDialog(Order order) {
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
                        order.id,
                        status,
                      );
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

  void _showTrackingNumberDialog(Order order) {
    final controller = TextEditingController(text: order.trackingNumber);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Tracking Number'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Tracking Number',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await context.read<OrderService>().updateTrackingNumber(
                      order.id,
                      controller.text,
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tracking number updated')),
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
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await context.read<OrderService>().cancelOrder(order.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Order cancelled')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.toString()}')),
          );
        }
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
        onRetry: _loadOrders,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search orders...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Order>>(
              stream: context.read<OrderService>().streamOrders(
                    status: _selectedStatus,
                    searchQuery: _searchQuery,
                  ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return error.ErrorView(
                    message: 'Failed to load orders',
                    onRetry: _loadOrders,
                  );
                }

                if (!snapshot.hasData) {
                  return const LoadingView();
                }

                final orders = snapshot.data!;

                if (orders.isEmpty) {
                  return const Center(
                    child: Text('No orders found'),
                  );
                }

                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: InkWell(
                        onTap: () =>
                            NavigationService.navigateToOrderDetail(order.id),
                        child: ExpansionTile(
                          title: Text('Order #${order.id}'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer: ${order.customerName}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                'Status: ${order.status.toString().split('.').last}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                'Total: \$${order.total.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Order Details',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  ...order.items.map((item) => ListTile(
                                        title: Text(item.productName),
                                        subtitle: Text(
                                            'Quantity: ${item.quantity} x \$${item.price.toStringAsFixed(2)}'),
                                        trailing: Text(
                                            '\$${item.total.toStringAsFixed(2)}'),
                                      )),
                                  const Divider(),
                                  Text(
                                    'Customer Information',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Email: ${order.customerEmail}'),
                                  Text('Phone: ${order.customerPhone}'),
                                  Text('Address: ${order.shippingAddress}'),
                                  const Divider(),
                                  Text(
                                    'Payment Information',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Text('Method: ${order.paymentMethod}'),
                                  Text('Status: ${order.paymentStatus}'),
                                  if (order.trackingNumber != null)
                                    Text('Tracking: ${order.trackingNumber}'),
                                  const Divider(),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () =>
                                            _showStatusUpdateDialog(order),
                                        child: const Text('Update Status'),
                                      ),
                                      if (order.status ==
                                          OrderStatus.processing)
                                        ElevatedButton(
                                          onPressed: () =>
                                              _showTrackingNumberDialog(order),
                                          child: const Text('Add Tracking'),
                                        ),
                                      if (order.status !=
                                              OrderStatus.cancelled &&
                                          order.status != OrderStatus.refunded)
                                        ElevatedButton(
                                          onPressed: () => _cancelOrder(order),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                          ),
                                          child: const Text('Cancel Order'),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
