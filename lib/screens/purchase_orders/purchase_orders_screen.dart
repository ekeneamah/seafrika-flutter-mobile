import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/models/purchase_order.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/purchase_order_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart' as loading;

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _searchQuery = '';
  String? _selectedSupplierId;
  PurchaseOrderStatus? _selectedStatus;
  bool _isLoadingMore = false;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  final int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreOrders();
    }
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final purchaseOrderService = context.read<PurchaseOrderService>();
      final orders = await purchaseOrderService
          .streamPurchaseOrders(
            supplierId: _selectedSupplierId,
            status: _selectedStatus,
            searchQuery: _searchQuery,
            lastDocument: _lastDocument,
            limit: _pageSize,
          )
          .first;

      if (orders.length < _pageSize) {
        _hasMore = false;
      }

      if (orders.isNotEmpty) {
        final snapshot = await FirebaseFirestore.instance
            .collection('vendors')
            .doc(orders.last.vendorId)
            .collection('purchase_orders')
            .doc(orders.last.id)
            .get();
        _lastDocument = snapshot;
      }

      setState(() => _isLoadingMore = false);
    } catch (e) {
      setState(() => _isLoadingMore = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load more orders')),
        );
      }
    }
  }

  void _resetPagination() {
    setState(() {
      _lastDocument = null;
      _hasMore = true;
      _isLoadingMore = false;
    });
  }

  void _onCreatePurchaseOrder() {
    NavigationService.navigateToCreatePurchaseOrder();
  }

  void _onPurchaseOrderTap(PurchaseOrder order) {
    NavigationService.navigateToPurchaseOrderDetail(order.id);
  }

  void _onEditPurchaseOrder(PurchaseOrder order) {
    NavigationService.navigateToEditPurchaseOrder(order.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Orders'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search orders...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                                _resetPagination();
                              });
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _resetPagination();
                    });
                  },
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusChip('All', null),
                      ...PurchaseOrderStatus.values.map(
                        (status) => _buildStatusChip(
                          status.toString().split('.').last,
                          status,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<PurchaseOrder>>(
              stream: context.read<PurchaseOrderService>().streamPurchaseOrders(
                    supplierId: _selectedSupplierId,
                    status: _selectedStatus,
                    searchQuery: _searchQuery,
                    lastDocument: _lastDocument,
                    limit: _pageSize,
                  ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return error.ErrorView(
                    message: 'Failed to load purchase orders',
                    onRetry: () {
                      setState(() {
                        _resetPagination();
                      });
                    },
                  );
                }

                if (!snapshot.hasData) {
                  return loading.LoadingView();
                }

                final orders = snapshot.data!;

                if (orders.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.shopping_cart,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Purchase Orders',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Create your first purchase order',
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == orders.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    final order = orders[index];
                    return Card(
                      child: ListTile(
                        onTap: () {
                          _onPurchaseOrderTap(order);
                        },
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(order.status),
                          child: Icon(
                            _getStatusIcon(order.status),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(order.orderNumber),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.supplierName,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              '${order.items.length} items',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${order.totalAmount.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              order.status.toString().split('.').last,
                              style: TextStyle(
                                color: _getStatusColor(order.status),
                                fontWeight: FontWeight.bold,
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
      floatingActionButton: FloatingActionButton(
        onPressed: _onCreatePurchaseOrder,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatusChip(String label, PurchaseOrderStatus? status) {
    final isSelected = status == _selectedStatus;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedStatus = selected ? status : null;
            _resetPagination();
          });
        },
      ),
    );
  }

  Color _getStatusColor(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return Colors.grey;
      case PurchaseOrderStatus.pending:
        return Colors.orange;
      case PurchaseOrderStatus.approved:
        return Colors.blue;
      case PurchaseOrderStatus.processing:
        return Colors.purple;
      case PurchaseOrderStatus.shipped:
        return Colors.indigo;
      case PurchaseOrderStatus.delivered:
        return Colors.green;
      case PurchaseOrderStatus.cancelled:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.draft:
        return Icons.edit;
      case PurchaseOrderStatus.pending:
        return Icons.hourglass_empty;
      case PurchaseOrderStatus.approved:
        return Icons.check_circle;
      case PurchaseOrderStatus.processing:
        return Icons.sync;
      case PurchaseOrderStatus.shipped:
        return Icons.local_shipping;
      case PurchaseOrderStatus.delivered:
        return Icons.done_all;
      case PurchaseOrderStatus.cancelled:
        return Icons.cancel;
    }
  }
}
