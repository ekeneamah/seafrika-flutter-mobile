import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vendor_app/models/purchase_order.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/purchase_order_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart' as loading;

class PurchaseOrderDetailScreen extends StatefulWidget {
  final String orderId;

  const PurchaseOrderDetailScreen({super.key, required this.orderId});

  @override
  State<PurchaseOrderDetailScreen> createState() =>
      _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  bool _isLoading = false;
  PurchaseOrder? _order;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() => _isLoading = true);
    try {
      final purchaseOrderService = context.read<PurchaseOrderService>();
      _order = await purchaseOrderService.fetchPurchaseOrder(widget.orderId);
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load purchase order')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(PurchaseOrderStatus newStatus) async {
    if (_order == null) return;

    setState(() => _isLoading = true);
    try {
      final purchaseOrderService = context.read<PurchaseOrderService>();
      await purchaseOrderService.updatePurchaseOrderStatus(
        widget.orderId,
        newStatus,
      );
      await _loadOrder();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update status')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Purchase Order'),
        content:
            const Text('Are you sure you want to delete this purchase order?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final purchaseOrderService = context.read<PurchaseOrderService>();
      await purchaseOrderService.deletePurchaseOrder(widget.orderId);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete purchase order')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
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

  List<PurchaseOrderStatus> _getAvailableStatusUpdates(
      PurchaseOrderStatus currentStatus) {
    switch (currentStatus) {
      case PurchaseOrderStatus.draft:
        return [PurchaseOrderStatus.pending, PurchaseOrderStatus.cancelled];
      case PurchaseOrderStatus.pending:
        return [PurchaseOrderStatus.approved, PurchaseOrderStatus.cancelled];
      case PurchaseOrderStatus.approved:
        return [PurchaseOrderStatus.processing, PurchaseOrderStatus.cancelled];
      case PurchaseOrderStatus.processing:
        return [PurchaseOrderStatus.shipped, PurchaseOrderStatus.cancelled];
      case PurchaseOrderStatus.shipped:
        return [PurchaseOrderStatus.delivered, PurchaseOrderStatus.cancelled];
      case PurchaseOrderStatus.delivered:
        return [];
      case PurchaseOrderStatus.cancelled:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: loading.LoadingView(),
        ),
      );
    }

    if (_order == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Purchase Order Details'),
        ),
        body: error.ErrorView(
          message: 'Purchase order not found',
          onRetry: _loadOrder,
        ),
      );
    }

    final availableStatusUpdates = _getAvailableStatusUpdates(_order!.status);

    return Scaffold(
      appBar: AppBar(
        title: Text('Order #${_order!.orderNumber}'),
        actions: [
          if (_order!.status == PurchaseOrderStatus.draft)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                NavigationService.navigateToEditPurchaseOrder(_order!.id);
              },
            ),
          if (_order!.status == PurchaseOrderStatus.draft)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteOrder,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _getStatusColor(_order!.status),
                        child: Icon(
                          _getStatusIcon(_order!.status),
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Status: ${_order!.status.toString().split('.').last}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              'Created: ${_order!.createdAt.toLocal().toString().split('.')[0]}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  Text(
                    'Supplier: ${_order!.supplierName}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_order!.expectedDeliveryDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Expected Delivery: ${_order!.expectedDeliveryDate!.toLocal().toString().split(' ')[0]}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (_order!.actualDeliveryDate != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Actual Delivery: ${_order!.actualDeliveryDate!.toLocal().toString().split(' ')[0]}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  if (_order!.notes != null && _order!.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Notes:',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(_order!.notes!),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Items',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _order!.items.length,
                    itemBuilder: (context, index) {
                      final item = _order!.items[index];
                      return ListTile(
                        title: Text(item.productName),
                        subtitle: Text(
                          '${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}',
                        ),
                        trailing: Text(
                          '\$${(item.quantity * item.unitPrice).toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      );
                    },
                  ),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Amount',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        '\$${_order!.totalAmount.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).primaryColor,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: availableStatusUpdates.isNotEmpty
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Update Status',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: availableStatusUpdates.map((status) {
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ElevatedButton(
                              onPressed: () => _updateStatus(status),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _getStatusColor(status),
                              ),
                              child: Text(
                                status.toString().split('.').last,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
