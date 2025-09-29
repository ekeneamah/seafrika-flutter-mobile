import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/order.dart';
import '../../providers/service_providers.dart';
import '../../providers/business_context_provider.dart';
import '../../widgets/error_view.dart' as error;
import '../../widgets/empty_view.dart';
import 'create_order_screen.dart';
import 'order_details_screen.dart';
import 'business_selection_modal.dart';

class OrderManagementScreen extends ConsumerStatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  ConsumerState<OrderManagementScreen> createState() =>
      _OrderManagementScreenState();
}

class _OrderManagementScreenState extends ConsumerState<OrderManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  OrderStatus? _selectedStatus;
  bool _isLoading = false;
  List<Order> _orders = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load orders when dependencies change (including business context)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get business context
      final businessContext = ref.read(businessContextProvider);
      if (businessContext == null) {
        setState(() {
          _error = 'No business selected. Please select a business first.';
          _isLoading = false;
        });
        return;
      }

      final orderService = ref.read(orderManagementServiceProvider);
      final orders = await orderService.getOrders(
        businessId: businessContext.id,
        status: _selectedStatus,
        limit: 50,
      );

      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Order Management'),
            Consumer(
              builder: (context, ref, child) {
                final businessContext = ref.watch(businessContextProvider);
                if (businessContext != null) {
                  return Text(
                    businessContext.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: Colors.grey,
                    ),
                  );
                }
                return const Text(
                  'No Business Selected',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.red,
                  ),
                );
              },
            ),
          ],
        ),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final businessContext = ref.watch(businessContextProvider);
              if (businessContext == null) {
                return IconButton(
                  icon: const Icon(Icons.business),
                  onPressed: _showBusinessSelectionModal,
                  tooltip: 'Select Business',
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'All Orders', icon: Icon(Icons.list_alt)),
            Tab(text: 'Pending', icon: Icon(Icons.pending)),
            Tab(text: 'Processing', icon: Icon(Icons.sync)),
            Tab(text: 'Shipped', icon: Icon(Icons.local_shipping)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          ],
          onTap: (index) {
            _selectedStatus = _getStatusForTab(index);
            _loadOrders();
          },
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList(),
          _buildOrdersList(status: OrderStatus.pending),
          _buildOrdersList(status: OrderStatus.processing),
          _buildOrdersList(status: OrderStatus.shipped),
          _buildAnalyticsView(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createTestOrder,
        tooltip: 'Create New Order',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildOrdersList({OrderStatus? status}) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return error.ErrorView(
        message: _error!,
        onRetry: _loadOrders,
      );
    }

    final filteredOrders = status != null
        ? _orders.where((order) => order.status == status).toList()
        : _orders;

    if (filteredOrders.isEmpty) {
      // Check if the issue is no business selected
      final businessContext = ref.read(businessContextProvider);
      if (businessContext == null) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.business_center,
                size: 64,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              const Text(
                'No Business Selected',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please select a business to view orders.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showBusinessSelectionModal,
                icon: const Icon(Icons.business),
                label: const Text('Select Business'),
              ),
            ],
          ),
        );
      }

      return const EmptyView(
        icon: Icons.receipt_long,
        title: 'No Orders Found',
        message: 'No orders available for this business',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredOrders.length,
        itemBuilder: (context, index) {
          final order = filteredOrders[index];
          return _buildOrderCard(order);
        },
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _viewOrderDetails(order),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order #${order.id.substring(0, 8)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  _buildStatusChip(order.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.customerName,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '${order.items.length} items • \$${order.total.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(order.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (order.trackingNumber != null) ...[
                    Icon(Icons.local_shipping,
                        size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      order.trackingNumber!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    'View Details',
                    Icons.visibility,
                    () => _viewOrderDetails(order),
                  ),
                  _buildActionButton(
                    'Track',
                    Icons.location_on,
                    () => _trackOrder(order),
                  ),
                  _buildActionButton(
                    'Tasks',
                    Icons.task,
                    () => _viewOrderTasks(order),
                  ),
                  if (order.status == OrderStatus.pending)
                    _buildActionButton(
                      'Process',
                      Icons.play_arrow,
                      () => _processOrder(order),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case OrderStatus.pending:
        backgroundColor = Colors.orange.shade100.withValues(alpha: 1.0);
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

  Widget _buildActionButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: Theme.of(context).primaryColor),
            const SizedBox(height: 2),
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

  Widget _buildAnalyticsView() {
    return FutureBuilder<Map<String, dynamic>>(
      future: ref.read(orderManagementServiceProvider).getOrderAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return error.ErrorView(
            message: snapshot.error.toString(),
            onRetry: () => setState(() {}),
          );
        }

        final analytics = snapshot.data ?? {};
        return _buildAnalyticsCards(analytics);
      },
    );
  }

  Widget _buildAnalyticsCards(Map<String, dynamic> analytics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Order Analytics',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildAnalyticsCard(
                'Total Orders',
                '${analytics['totalOrders'] ?? 0}',
                Icons.receipt_long,
                Colors.blue,
              ),
              _buildAnalyticsCard(
                'Total Revenue',
                '\$${(analytics['totalRevenue'] ?? 0.0).toStringAsFixed(2)}',
                Icons.attach_money,
                Colors.green,
              ),
              _buildAnalyticsCard(
                'Avg Order Value',
                '\$${(analytics['averageOrderValue'] ?? 0.0).toStringAsFixed(2)}',
                Icons.trending_up,
                Colors.orange,
              ),
              _buildAnalyticsCard(
                'Completion Rate',
                '${((analytics['completionRate'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                Icons.check_circle,
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Order Status Distribution',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ..._buildStatusCards(analytics['statusCounts'] ?? {}),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildStatusCards(Map<String, dynamic> statusCounts) {
    return statusCounts.entries.map((entry) {
      final status = entry.key;
      final count = entry.value;

      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: _buildStatusIcon(status),
          title: Text(status.toUpperCase()),
          trailing: Text(
            '$count',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildStatusIcon(String status) {
    IconData iconData;
    Color color;

    switch (status) {
      case 'pending':
        iconData = Icons.pending;
        color = Colors.orange;
        break;
      case 'confirmed':
        iconData = Icons.check_circle_outline;
        color = Colors.blue;
        break;
      case 'processing':
        iconData = Icons.sync;
        color = Colors.yellow.shade700;
        break;
      case 'shipped':
        iconData = Icons.local_shipping;
        color = Colors.purple;
        break;
      case 'delivered':
        iconData = Icons.check_circle;
        color = Colors.green;
        break;
      case 'cancelled':
        iconData = Icons.cancel;
        color = Colors.red;
        break;
      default:
        iconData = Icons.help_outline;
        color = Colors.grey;
    }

    return Icon(iconData, color: color);
  }

  OrderStatus? _getStatusForTab(int index) {
    switch (index) {
      case 0:
        return null; // All orders
      case 1:
        return OrderStatus.pending;
      case 2:
        return OrderStatus.processing;
      case 3:
        return OrderStatus.shipped;
      default:
        return null;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Orders'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Orders'),
              leading: Radio<OrderStatus?>(
                value: null,
                groupValue: _selectedStatus,
                onChanged: (value) {
                  setState(() => _selectedStatus = value);
                  Navigator.pop(context);
                  _loadOrders();
                },
              ),
            ),
            ...OrderStatus.values.map(
              (status) => ListTile(
                title: Text(status.toString().split('.').last.toUpperCase()),
                leading: Radio<OrderStatus?>(
                  value: status,
                  groupValue: _selectedStatus,
                  onChanged: (value) {
                    setState(() => _selectedStatus = value);
                    Navigator.pop(context);
                    _loadOrders();
                  },
                ),
              ),
            ),
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

  Future<void> _viewOrderDetails(Order order) async {
    try {
      final orderService = ref.read(orderManagementServiceProvider);
      final orderDetails = await orderService.getOrderDetails(order.id);

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailsScreen(
            orderDetails: orderDetails,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading order details: $e')),
        );
      }
    }
  }

  Future<void> _trackOrder(Order order) async {
    try {
      final orderService = ref.read(orderManagementServiceProvider);
      final delivery =
          await orderService.getDeliveryTrackingByOrderId(order.id);

      if (!mounted) return;

      if (delivery != null) {
        // TODO: Navigate to proper delivery tracking screen
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Delivery tracking screen - coming soon')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No delivery tracking available for this order')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading delivery tracking: $e')),
        );
      }
    }
  }

  Future<void> _viewOrderTasks(Order order) async {
    try {
      final orderService = ref.read(orderManagementServiceProvider);
      // Load order tasks
      await orderService.getOrderTasks(order.id);

      if (!mounted) return;

      // TODO: Navigate to proper order tasks screen
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order tasks screen - coming soon')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading order tasks: $e')),
        );
      }
    }
  }

  Future<void> _processOrder(Order order) async {
    try {
      final orderService = ref.read(orderManagementServiceProvider);
      await orderService.updateOrderStatus(order.id, OrderStatus.confirmed);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Order confirmed and processing started')),
        );
        _loadOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error processing order: $e')),
        );
      }
    }
  }

  Future<void> _createTestOrder() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateOrderScreen(),
      ),
    );

    if (result is String) {
      // Refresh the orders list
      _loadOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order #$result created successfully')),
        );
      }
    }
  }

  Future<void> _showBusinessSelectionModal() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const BusinessSelectionModal(),
    );

    // If a business was selected, reload the orders
    if (result == true) {
      _loadOrders();
    }
  }
}
