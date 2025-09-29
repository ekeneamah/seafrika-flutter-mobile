/// A screen that displays detailed information about a specific inventory item.
///
/// This screen shows:
/// - Product images in a carousel (if available)
/// - Current stock status and quantity
/// - Unit price and total value
/// - Location and timestamps
/// - Notes (if any)
///
/// Actions available:
/// - Sell to customer
/// - Create booking
/// - Push to external store
/// - Add quantity
/// - Request from supplier
/// - View history
/// - Edit details

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart' as theme;
import 'package:vendor_app/models/business_inventory.dart';
import 'package:vendor_app/models/store_inventory.dart';
import 'package:vendor_app/models/booking.dart';
import 'package:vendor_app/models/product.dart';
import 'package:vendor_app/providers/business_inventory_provider.dart'
    as biz_inventory;
import 'package:vendor_app/providers/store_distribution_provider.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/store_inventory_service.dart';
import 'package:vendor_app/services/booking_service.dart';
import 'package:vendor_app/services/product_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error_view;
import 'package:vendor_app/widgets/loading_view.dart' as loading_view;
import 'package:vendor_app/screens/inventory/supplier_requests_screen.dart';
import 'package:vendor_app/screens/inventory/create_inventory_screen.dart';
import 'package:vendor_app/screens/inventory/inventory_history_screen.dart';
import 'package:vendor_app/screens/inventory/business_inventory_detail_screen.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vendor_app/providers/inventory_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class InventoryDetailScreen extends ConsumerWidget {
  final String businessInventoryId;

  const InventoryDetailScreen({
    Key? key,
    required this.businessInventoryId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessInventoryAsync = ref.watch(
        biz_inventory.businessInventoryDetailProvider(businessInventoryId));

    return businessInventoryAsync.when(
      loading: () => const Scaffold(
        body: loading_view.LoadingView(),
      ),
      error: (error, stackTrace) => Scaffold(
        body: error_view.ErrorView(
          message: 'Failed to load inventory details: $error',
          onRetry: () => ref.refresh(biz_inventory
              .businessInventoryDetailProvider(businessInventoryId)),
        ),
      ),
      data: (businessInventory) {
        if (businessInventory == null) {
          return Scaffold(
            body: error_view.ErrorView(
              message: 'Inventory item not found',
              onRetry: () => ref.refresh(biz_inventory
                  .businessInventoryDetailProvider(businessInventoryId)),
            ),
          );
        }

        return _buildDetailScreen(context, ref, businessInventory);
      },
    );
  }

  Widget _buildDetailScreen(BuildContext context, WidgetRef ref,
      BusinessInventory businessInventory) {
    return Scaffold(
      backgroundColor: theme.AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Inventory Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showActionMenu(context, ref, businessInventory),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.refresh(biz_inventory
              .businessInventoryDetailProvider(businessInventoryId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (businessInventory.displayImageUrl != null &&
                businessInventory.displayImageUrl!.isNotEmpty) ...[
              _buildImageCarousel(context, businessInventory.displayImageUrl!),
              const SizedBox(height: 16),
            ],
            _buildStatusCard(context, businessInventory),
            const SizedBox(height: 16),
            _buildDetailsCard(context, businessInventory),
            const SizedBox(height: 16),
            _buildStoreDistributionCard(context, ref, businessInventory),
            if (businessInventory.notes != null &&
                businessInventory.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildNotesCard(context, businessInventory),
            ],
          ],
        ),
      ),
    );
  }

  void _showActionMenu(BuildContext context, WidgetRef ref,
      BusinessInventory businessInventory) {
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
                _showSellDialog(context, ref, businessInventory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Sell via Booking'),
              onTap: () {
                Navigator.pop(context);
                _showBookingDialog(context, ref, businessInventory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Push to External Store'),
              onTap: () {
                Navigator.pop(context);
                _showStoreDialog(context, ref, businessInventory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle),
              title: const Text('Add Quantity'),
              onTap: () {
                Navigator.pop(context);
                _showAddQuantityDialog(context, ref, businessInventory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping),
              title: const Text('Request from Supplier'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SupplierRequestsScreen(
                      inventoryId: businessInventoryId,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('View History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InventoryHistoryScreen(
                      inventoryId: businessInventoryId,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Details'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BusinessInventoryDetailScreen(
                      businessInventoryId: businessInventory.id,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSellDialog(BuildContext context, WidgetRef ref,
      BusinessInventory businessInventory) async {
    final quantityController = TextEditingController();
    final priceController = TextEditingController(
      text: businessInventory.sellingPrice.toString(),
    );
    final customerController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sell to Customer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: customerController,
              decoration: const InputDecoration(
                labelText: 'Customer Name/ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Price per Unit',
                border: OutlineInputBorder(),
                prefixText: '\$',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (quantityController.text.isEmpty ||
                  priceController.text.isEmpty ||
                  customerController.text.isEmpty) {
                return;
              }
              Navigator.pop(context, {
                'customer': customerController.text,
                'quantity': int.parse(quantityController.text),
                'price': double.parse(priceController.text),
              });
            },
            child: const Text('Sell'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        // Since we're working with BusinessInventory, we need to use BusinessInventoryService
        final businessInventoryService =
            ref.read(biz_inventory.businessInventoryServiceProvider);
        // For now, we'll call updateAvailableQuantity to reduce the available quantity
        await businessInventoryService.updateAvailableQuantity(
          businessInventoryId: businessInventory.id,
          quantityChange: -(result['quantity'] as int),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sale recorded successfully')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to record sale')),
        );
      }
    }
  }

  Future<void> _showBookingDialog(BuildContext context, WidgetRef ref,
      BusinessInventory businessInventory) async {
    final bookingController = TextEditingController();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Booking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: bookingController,
              decoration: const InputDecoration(
                labelText: 'Customer ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Customer Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Customer Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Customer Phone',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (bookingController.text.isEmpty ||
                  nameController.text.isEmpty ||
                  emailController.text.isEmpty ||
                  phoneController.text.isEmpty) return;
              Navigator.pop(context, {
                'id': bookingController.text,
                'name': nameController.text,
                'email': emailController.text,
                'phone': phoneController.text,
              });
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        // TODO: Implement booking functionality for BusinessInventory
        // This would need to create a booking record and reserve quantity from business inventory

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Booking functionality not yet implemented for business inventory')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create booking: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showStoreDialog(BuildContext context, WidgetRef ref,
      BusinessInventory businessInventory) async {
    final storeController = TextEditingController();
    final quantityController = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Push to External Store'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: storeController,
              decoration: const InputDecoration(
                labelText: 'Store Name/ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity to Push',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (storeController.text.isEmpty ||
                  quantityController.text.isEmpty) {
                return;
              }
              Navigator.pop(context, {
                'store': storeController.text,
                'quantity': int.parse(quantityController.text),
              });
            },
            child: const Text('Push'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        // TODO: Implement store allocation for BusinessInventory
        // This would need to allocate business inventory to a specific store
        final businessInventoryService =
            ref.read(biz_inventory.businessInventoryServiceProvider);
        await businessInventoryService.updateAvailableQuantity(
          businessInventoryId: businessInventory.id,
          quantityChange: -(result['quantity'] as int),
        );

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Items pushed to store successfully')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to push items: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showAddQuantityDialog(BuildContext context, WidgetRef ref,
      BusinessInventory businessInventory) async {
    final quantityController = TextEditingController();
    final priceController = TextEditingController(
      text: businessInventory.sellingPrice.toString(),
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Quantity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Quantity to Add',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Purchase Price per Unit',
                border: OutlineInputBorder(),
                prefixText: '\$',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (quantityController.text.isEmpty ||
                  priceController.text.isEmpty) {
                return;
              }
              try {
                await ref
                    .read(inventoryDetailProvider(businessInventoryId).notifier)
                    .addQuantity(
                      quantity: int.parse(quantityController.text),
                      price: double.parse(priceController.text),
                    );
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Quantity added successfully')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Failed to add quantity: ${e.toString()}')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
      BuildContext context, BusinessInventory businessInventory) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: businessInventory.isLowStock
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  child: Icon(
                    Icons.inventory,
                    color: businessInventory.isLowStock
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        businessInventory.productName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        businessInventory.isLowStock
                            ? 'Low Stock'
                            : 'Stock Level Normal',
                        style: TextStyle(
                          color: businessInventory.isLowStock
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              context,
              'Current Quantity',
              businessInventory.availableQuantity.toString(),
            ),
            _buildInfoRow(
              context,
              'Unit Price',
              '\$${businessInventory.sellingPrice.toStringAsFixed(2)}',
            ),
            _buildInfoRow(
              context,
              'Total Value',
              '\$${businessInventory.totalValue.toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(
      BuildContext context, BusinessInventory businessInventory) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Details',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (businessInventory.notes != null)
              _buildInfoRow(
                context,
                'Notes',
                businessInventory.notes!,
              ),
            _buildInfoRow(
              context,
              'Last Updated',
              _formatDate(businessInventory.updatedAt),
            ),
            _buildInfoRow(
              context,
              'Created At',
              _formatDate(businessInventory.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(
      BuildContext context, BusinessInventory businessInventory) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(businessInventory.notes ?? 'No notes available'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          Text(value),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

  Widget _buildStoreDistributionCard(BuildContext context, WidgetRef ref,
      BusinessInventory businessInventory) {
    final storeDistributionParams = StoreDistributionParams(
      businessId: businessInventory.businessId,
      businessInventoryId: businessInventory.id,
    );

    final storeDistributionAsync =
        ref.watch(storeDistributionProvider(storeDistributionParams));

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
                Text(
                  'Store Distribution',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => ref.refresh(
                      storeDistributionProvider(storeDistributionParams)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            storeDistributionAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text('Error loading store distribution: $error'),
                      TextButton(
                        onPressed: () => ref.refresh(
                            storeDistributionProvider(storeDistributionParams)),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (storeDistribution) {
                if (storeDistribution.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.store_outlined,
                              color: Colors.grey, size: 48),
                          SizedBox(height: 8),
                          Flexible(
                            child: Text(
                              'Not allocated to any stores yet',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: storeDistribution
                      .map((store) => _buildStoreDistributionItem(store))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreDistributionItem(Map<String, dynamic> store) {
    final quantity = store['quantity'] as int? ?? 0;
    final minimumQuantity = store['minimumQuantity'] as int? ?? 0;
    final isLowStock = store['isLowStock'] as bool? ?? false;
    final lastUpdated = store['lastUpdated'] as Timestamp?;
    final storeName = store['storeName'] as String? ?? 'Unknown Store';
    final location = store['location'] as String? ?? '';
    final status = store['status'] as String? ?? 'active';

    final Color statusColor =
        quantity > 0 ? (isLowStock ? Colors.orange : Colors.green) : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storeName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    if (location.isNotEmpty)
                      Text(
                        location,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  '$quantity qty',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Min: $minimumQuantity',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              Expanded(
                child: Text(
                  'Status: ${status.toUpperCase()}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              if (lastUpdated != null)
                Expanded(
                  child: Text(
                    'Updated: ${_formatDate(lastUpdated.toDate())}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(BuildContext context, String imageUrl) {
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
