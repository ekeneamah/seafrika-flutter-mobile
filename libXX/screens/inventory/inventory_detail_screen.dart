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
import 'package:vendor_app/models/inventory.dart';
import 'package:vendor_app/models/booking.dart';
import 'package:vendor_app/models/product.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/inventory_service.dart';
import 'package:vendor_app/services/booking_service.dart';
import 'package:vendor_app/services/product_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error_view;
import 'package:vendor_app/widgets/loading_view.dart' as loading_view;
import 'package:vendor_app/screens/inventory/supplier_requests_screen.dart';
import 'package:vendor_app/screens/inventory/create_inventory_screen.dart';
import 'package:vendor_app/screens/inventory/inventory_history_screen.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vendor_app/providers/inventory_provider.dart';

class InventoryDetailScreen extends ConsumerWidget {
  final String inventoryId;

  const InventoryDetailScreen({
    Key? key,
    required this.inventoryId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inventoryDetailProvider(inventoryId));

    if (state.isLoading) {
      return const Scaffold(
        body: loading_view.LoadingView(),
      );
    }

    if (state.error != null) {
      return Scaffold(
        body: error_view.ErrorView(
          message: state.error!,
          onRetry: () {
            ref
                .read(inventoryDetailProvider(inventoryId).notifier)
                .loadInventory();
          },
        ),
      );
    }

    final inventory = state.inventory;
    final product = state.product;

    if (inventory == null || product == null) {
      return error_view.ErrorView(
        message: 'Inventory or product not found',
        onRetry: () {
          ref
              .read(inventoryDetailProvider(inventoryId).notifier)
              .loadInventory();
        },
      );
    }

    return Scaffold(
      backgroundColor: theme.AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Inventory Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showActionMenu(context, ref, inventory, product),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref
            .read(inventoryDetailProvider(inventoryId).notifier)
            .loadInventory(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (product.images.isNotEmpty) ...[
              _buildImageCarousel(context, product),
              const SizedBox(height: 16),
            ],
            _buildStatusCard(context, inventory),
            const SizedBox(height: 16),
            _buildDetailsCard(context, inventory),
            if (inventory.notes != null) ...[
              const SizedBox(height: 16),
              _buildNotesCard(context, inventory),
            ],
          ],
        ),
      ),
    );
  }

  void _showActionMenu(BuildContext context, WidgetRef ref, Inventory inventory,
      Product product) {
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
                _showSellDialog(context, ref, inventory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Sell via Booking'),
              onTap: () {
                Navigator.pop(context);
                _showBookingDialog(context, ref, inventory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.store),
              title: const Text('Push to External Store'),
              onTap: () {
                Navigator.pop(context);
                _showStoreDialog(context, ref, inventory);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_circle),
              title: const Text('Add Quantity'),
              onTap: () {
                Navigator.pop(context);
                _showAddQuantityDialog(context, ref, inventory);
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
                      inventoryId: inventoryId,
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
                      inventoryId: inventoryId,
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
                    builder: (context) => CreateInventoryScreen(
                      inventory: inventory,
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

  Future<void> _showSellDialog(
      BuildContext context, WidgetRef ref, Inventory inventory) async {
    final quantityController = TextEditingController();
    final priceController = TextEditingController(
      text: inventory.unitPrice.toString(),
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
        await ref
            .read(inventoryDetailProvider(inventoryId).notifier)
            .sellInventory(
              quantity: result['quantity'],
              price: result['price'],
              customerId: result['customer'],
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

  Future<void> _showBookingDialog(
      BuildContext context, WidgetRef ref, Inventory inventory) async {
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
        final booking = await ref
            .read(inventoryDetailProvider(inventoryId).notifier)
            .createBooking(
              customerId: result['id']!,
              customerName: result['name']!,
              customerEmail: result['email']!,
              customerPhone: result['phone']!,
              bookingDate: DateTime.now(),
              items: [
                BookingItem(
                  inventoryId: inventoryId,
                  productName: inventory.productName,
                  quantity: 1,
                  unitPrice: inventory.unitPrice,
                ),
              ],
              notes: 'Created from inventory item $inventoryId',
            );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking created successfully')),
        );
        NavigationService.navigateToBookingDetail(booking.id);
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create booking: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _showStoreDialog(
      BuildContext context, WidgetRef ref, Inventory inventory) async {
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
        await ref
            .read(inventoryDetailProvider(inventoryId).notifier)
            .pushToStore(
              storeId: result['store'],
              quantity: result['quantity'],
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

  Future<void> _showAddQuantityDialog(
      BuildContext context, WidgetRef ref, Inventory inventory) async {
    final quantityController = TextEditingController();
    final priceController = TextEditingController(
      text: inventory.unitPrice.toString(),
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
                    .read(inventoryDetailProvider(inventoryId).notifier)
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

  Widget _buildStatusCard(BuildContext context, Inventory inventory) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: inventory.isLowStock
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  child: Icon(
                    Icons.inventory,
                    color: inventory.isLowStock ? Colors.red : Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inventory.productName,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        inventory.isLowStock
                            ? 'Low Stock'
                            : 'Stock Level Normal',
                        style: TextStyle(
                          color:
                              inventory.isLowStock ? Colors.red : Colors.green,
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
              inventory.quantity.toString(),
            ),
            _buildInfoRow(
              context,
              'Minimum Quantity',
              inventory.minimumQuantity.toString(),
            ),
            _buildInfoRow(
              context,
              'Unit Price',
              '\$${inventory.unitPrice.toStringAsFixed(2)}',
            ),
            _buildInfoRow(
              context,
              'Total Value',
              '\$${(inventory.quantity * inventory.unitPrice).toStringAsFixed(2)}',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, Inventory inventory) {
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
            if (inventory.location != null)
              _buildInfoRow(
                context,
                'Location',
                inventory.location!,
              ),
            _buildInfoRow(
              context,
              'Last Updated',
              _formatDate(inventory.updatedAt),
            ),
            _buildInfoRow(
              context,
              'Created At',
              _formatDate(inventory.createdAt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context, Inventory inventory) {
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
            Text(inventory.notes!),
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

  Widget _buildImageCarousel(BuildContext context, Product product) {
    final pageController = PageController();
    return Column(
      children: [
        SizedBox(
          height: 300,
          child: PageView.builder(
            controller: pageController,
            itemCount: product.images.length,
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: product.images[index],
                  fit: BoxFit.cover,
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
              );
            },
          ),
        ),
        if (product.images.length > 1) ...[
          const SizedBox(height: 16),
          SmoothPageIndicator(
            controller: pageController,
            count: product.images.length,
            effect: WormEffect(
              dotHeight: 8,
              dotWidth: 8,
              type: WormType.thin,
              activeDotColor: theme.AppTheme.primary,
              dotColor: Colors.grey[300]!,
            ),
          ),
        ],
      ],
    );
  }
}
