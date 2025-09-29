/// A screen that displays detailed information about a specific store inventory item.
///
/// This screen shows:
/// - Store-level inventory details
/// - Product information
/// - Stock status and quantities
/// - Store location and notes
/// - Store-specific actions
///
/// Actions available:
/// - Sell to customer
/// - Create booking
/// - Request from warehouse
/// - Edit store details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart' as theme;
import 'package:vendor_app/models/store_inventory.dart';
import 'package:vendor_app/services/store_inventory_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error_view;
import 'package:vendor_app/widgets/loading_view.dart' as loading_view;

/// Provider for store inventory service
final storeInventoryServiceProvider = Provider<StoreInventoryService>((ref) {
  return StoreInventoryService();
});

/// Provider for a single store inventory item
final storeInventoryDetailProvider =
    FutureProvider.family<StoreInventory?, StoreInventoryDetailParams>(
        (ref, params) async {
  final service = ref.read(storeInventoryServiceProvider);
  return service.getStoreInventoryById(
    businessId: params.businessId,
    storeId: params.storeId,
    inventoryId: params.inventoryId,
  );
});

/// Parameters for store inventory detail provider
class StoreInventoryDetailParams {
  final String businessId;
  final String storeId;
  final String inventoryId;

  const StoreInventoryDetailParams({
    required this.businessId,
    required this.storeId,
    required this.inventoryId,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StoreInventoryDetailParams &&
        other.businessId == businessId &&
        other.storeId == storeId &&
        other.inventoryId == inventoryId;
  }

  @override
  int get hashCode =>
      businessId.hashCode ^ storeId.hashCode ^ inventoryId.hashCode;
}

class StoreInventoryDetailScreen extends ConsumerWidget {
  final String businessId;
  final String storeId;
  final String inventoryId;

  const StoreInventoryDetailScreen({
    Key? key,
    required this.businessId,
    required this.storeId,
    required this.inventoryId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = StoreInventoryDetailParams(
      businessId: businessId,
      storeId: storeId,
      inventoryId: inventoryId,
    );
    final inventoryAsync = ref.watch(storeInventoryDetailProvider(params));

    return inventoryAsync.when(
      loading: () => const Scaffold(
        body: loading_view.LoadingView(),
      ),
      error: (error, stackTrace) => Scaffold(
        body: error_view.ErrorView(
          message: 'Failed to load store inventory: $error',
          onRetry: () => ref.refresh(storeInventoryDetailProvider(params)),
        ),
      ),
      data: (storeInventory) {
        if (storeInventory == null) {
          return Scaffold(
            body: error_view.ErrorView(
              message: 'Store inventory item not found',
              onRetry: () => ref.refresh(storeInventoryDetailProvider(params)),
            ),
          );
        }

        return _buildDetailScreen(context, ref, storeInventory, params);
      },
    );
  }

  Widget _buildDetailScreen(BuildContext context, WidgetRef ref,
      StoreInventory storeInventory, StoreInventoryDetailParams params) {
    return Scaffold(
      backgroundColor: theme.AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Store Inventory Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showActionMenu(context, ref, storeInventory),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          return Future.sync(
              () => ref.refresh(storeInventoryDetailProvider(params)));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(context, storeInventory),
            const SizedBox(height: 16),
            _buildDetailsCard(context, storeInventory),
            if (storeInventory.notes != null &&
                storeInventory.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildNotesCard(context, storeInventory),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context, StoreInventory storeInventory) {
    final bool isLowStock = storeInventory.isLowStock;
    final Color statusColor = storeInventory.quantity > 0
        ? (isLowStock ? Colors.orange : Colors.green)
        : Colors.red;
    final String statusText = storeInventory.status.toUpperCase();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
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
                    storeInventory.productName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatsItem(
                    'Current Stock',
                    '${storeInventory.quantity}',
                    Icons.inventory_2,
                    statusColor,
                  ),
                ),
                Expanded(
                  child: _buildStatsItem(
                    'Minimum',
                    '${storeInventory.minimumQuantity}',
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatsItem(
                    'Unit Price',
                    'KSh ${storeInventory.unitPrice.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatsItem(
                    'Total Value',
                    'KSh ${storeInventory.totalValue.toStringAsFixed(2)}',
                    Icons.price_change,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsItem(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(
      BuildContext context, StoreInventory storeInventory) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Store Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Store ID', storeInventory.storeId),
            _buildDetailRow('Business', storeInventory.businessName),
            _buildDetailRow('Category', storeInventory.category),
            if (storeInventory.location != null &&
                storeInventory.location!.isNotEmpty)
              _buildDetailRow('Location', storeInventory.location!),
            _buildDetailRow('Created', _formatDate(storeInventory.createdAt)),
            _buildDetailRow(
                'Last Updated', _formatDate(storeInventory.updatedAt)),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context, StoreInventory storeInventory) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(storeInventory.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showActionMenu(
      BuildContext context, WidgetRef ref, StoreInventory storeInventory) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('Sell to Customer'),
              onTap: () {
                Navigator.pop(context);
                _showNotImplementedDialog(context, 'Sell to Customer');
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Create Booking'),
              onTap: () {
                Navigator.pop(context);
                _showNotImplementedDialog(context, 'Create Booking');
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle),
              title: const Text('Request from Warehouse'),
              onTap: () {
                Navigator.pop(context);
                _showNotImplementedDialog(context, 'Request from Warehouse');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Store Details'),
              onTap: () {
                Navigator.pop(context);
                _showNotImplementedDialog(context, 'Edit Store Details');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showNotImplementedDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text('$feature feature is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
