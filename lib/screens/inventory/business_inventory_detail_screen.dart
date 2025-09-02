/// A screen that displays detailed information about a specific business inventory item.
///
/// This screen shows:
/// - Current warehouse status and quantities
/// - Cost price and total value
/// - Store distribution and allocations
/// - Creation and update timestamps
///
/// Actions available:
/// - Allocate to stores
/// - Add quantity to warehouse
/// - View history
/// - Edit details

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/config/theme.dart' as theme;
import 'package:vendor_app/models/business_inventory.dart';
import 'package:vendor_app/models/store.dart';
import 'package:vendor_app/providers/business_inventory_provider.dart' hide businessInventoryServiceProvider;
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/services/inventory_allocation_service.dart';
import 'package:vendor_app/services/store_inventory_service.dart';
import 'package:vendor_app/screens/inventory/store_inventory_detail_screen.dart';
import 'package:vendor_app/utils/logger.dart';
import 'package:vendor_app/widgets/error_view.dart' as error_view;
import 'package:vendor_app/widgets/loading_view.dart' as loading_view;

class BusinessInventoryDetailScreen extends ConsumerWidget {
  final String businessInventoryId;

  const BusinessInventoryDetailScreen({
    Key? key,
    required this.businessInventoryId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessInventoryAsync =
        ref.watch(businessInventoryDetailProvider(businessInventoryId));

    return businessInventoryAsync.when(
      loading: () => const Scaffold(
        body: loading_view.LoadingView(),
      ),
      error: (error, stackTrace) => Scaffold(
        body: error_view.ErrorView(
          message: 'Failed to load inventory details: $error',
          onRetry: () =>
              ref.refresh(businessInventoryDetailProvider(businessInventoryId)),
        ),
      ),
      data: (businessInventory) {
        if (businessInventory == null) {
          return Scaffold(
            body: error_view.ErrorView(
              message: 'Inventory item not found',
              onRetry: () => ref.refresh(
                  businessInventoryDetailProvider(businessInventoryId)),
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
        title: const Text('Business Inventory Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showActionMenu(context, ref, businessInventory),
          ),
        ],
      ),
      floatingActionButton: businessInventory.availableQuantity > 0
          ? FloatingActionButton.extended(
              onPressed: () {
                AppLogger.info('FAB - Allocate button pressed');
                _showStoreAllocationDialog(context, ref, businessInventory);
              },
              icon: const Icon(Icons.store),
              label: const Text('Allocate'),
              backgroundColor: theme.AppTheme.primary,
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async {
          return Future.sync(() => ref
              .refresh(businessInventoryDetailProvider(businessInventoryId)));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatusCard(context, businessInventory),
            const SizedBox(height: 16),
            _buildDetailsCard(context, businessInventory),
            const SizedBox(height: 16),
            _buildStoreDistributionCard(context, ref, businessInventory),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(
      BuildContext context, BusinessInventory businessInventory) {
    final bool isLowStock =
        businessInventory.availableQuantity <= 5; // Basic low stock check
    final Color statusColor = businessInventory.availableQuantity > 0
        ? (isLowStock ? Colors.orange : Colors.green)
        : Colors.red;
    final String statusText = businessInventory.availableQuantity > 0
        ? (isLowStock ? 'Low Stock' : 'In Stock')
        : 'Out of Stock';

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
                    businessInventory.productName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
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
                    'Total Quantity',
                    '${businessInventory.totalQuantity}',
                    Icons.inventory_2,
                    theme.AppTheme.primary,
                  ),
                ),
                Expanded(
                  child: _buildStatsItem(
                    'Available',
                    '${businessInventory.availableQuantity}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatsItem(
                    'Total Value',
                    'KSh ${businessInventory.totalValue.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatsItem(
                    'Cost Price',
                    'KSh ${businessInventory.costPrice.toStringAsFixed(2)}',
                    Icons.price_change,
                    Colors.orange,
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
      BuildContext context, BusinessInventory businessInventory) {
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
              'Details',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildDetailRow('Category', businessInventory.category),
            _buildDetailRow('Selling Price',
                'KSh ${businessInventory.sellingPrice.toStringAsFixed(2)}'),
            _buildDetailRow('Status', businessInventory.status.toUpperCase()),
            _buildDetailRow(
                'Created', _formatDate(businessInventory.createdAt)),
            _buildDetailRow(
                'Last Updated', _formatDate(businessInventory.updatedAt)),
            if (businessInventory.supplierId != null)
              _buildDetailRow('Supplier ID', businessInventory.supplierId!),
            if (businessInventory.purchaseOrderId != null)
              _buildDetailRow(
                  'Purchase Order', businessInventory.purchaseOrderId!),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreDistributionCard(BuildContext context, WidgetRef ref,
      BusinessInventory businessInventory) {
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
                Icon(
                  Icons.store,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Use store distribution data directly from business inventory
            if (businessInventory.storeDistribution == null ||
                businessInventory.storeDistribution!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.store_outlined, color: Colors.grey, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'Not allocated to any stores yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: businessInventory.storeDistribution!.values
                    .map((storeDistribution) =>
                        _buildStoreDistributionItemFromBusinessInventory(
                            context, ref, storeDistribution))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreDistributionItemFromBusinessInventory(BuildContext context,
      WidgetRef ref, StoreDistribution storeDistribution) {
    final Color statusColor =
        storeDistribution.allocatedQuantity > 0 ? Colors.green : Colors.red;

    return GestureDetector(
      onTap: () => _navigateToStoreInventoryDetail(
          context, ref, storeDistribution, businessInventoryId),
      child: Container(
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
              children: [
                // Store icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.store,
                    color: Colors.grey,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                // Store details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        storeDistribution.storeName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                // Quantity badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    '${storeDistribution.allocatedQuantity} qty',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                // Arrow icon to indicate it's tappable
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Last allocated date
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  'Last allocated: ${_formatDateTime(storeDistribution.lastAllocated)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
    BuildContext context, WidgetRef ref, BusinessInventory businessInventory) {
  showModalBottomSheet(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.add_circle),
            title: const Text('Add Quantity'),
            onTap: () {
              Navigator.pop(context);
              _showAddQuantityDialog(context, ref, businessInventory);
            },
          ),
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('View History'),
            onTap: () {
              Navigator.pop(context);
              // NavigationService.navigateTo('/business_inventory_history', arguments: {'businessInventoryId': businessInventoryId});
              _showNotImplementedDialog(context, 'History');
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Edit Details'),
            onTap: () {
              Navigator.pop(context);
              _showEditDetailsDialog(context, ref, businessInventory);
            },
          ),
        ],
      ),
    ),
  );
}

void _showStoreAllocationDialog(BuildContext context, WidgetRef ref,
    BusinessInventory businessInventory) async {
  AppLogger.info('_showStoreAllocationDialog called');
  
  // Check if there's available quantity
  if (businessInventory.availableQuantity <= 0) {
    AppLogger.warning('No available quantity to allocate');
    if (context.mounted) {
      _showErrorDialog(context, 'No Available Quantity',
          'This item has no available quantity to allocate to stores.');
    }
    return;
  }

  // Get stores from the store service
  final storeService = ref.read(storeServiceProvider);
  AppLogger.info('Got store service, about to fetch stores');

  // Check context before showing loading dialog
  if (!context.mounted) {
    AppLogger.warning('Context not mounted, aborting allocation dialog');
    return;
  }

  try {
    // Show loading while fetching stores
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    AppLogger.info('Loading dialog shown');

    // Fetch stores with timeout
    await storeService.fetchStores().timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw Exception('Fetching stores timed out. Please try again.');
      },
    );
    final stores = storeService.stores;
    AppLogger.info('Fetched ${stores.length} stores');

    // Check context before closing loading dialog
    if (context.mounted) {
      Navigator.of(context).pop();
      AppLogger.info('Loading dialog closed');
    }

    // Check context before showing error or next dialog
    if (!context.mounted) {
      AppLogger.warning('Context no longer mounted after fetching stores');
      return;
    }

    if (stores.isEmpty) {
      AppLogger.warning('No stores available');
      _showErrorDialog(context, 'No Stores Available',
          'You need to create stores first before allocating inventory.');
      return;
    }

    // Show store allocation dialog
    AppLogger.info('About to show store selection dialog');
    _showStoreSelectionDialog(context, ref, businessInventory, stores);
  } catch (e) {
    // Always close loading dialog if still open and context is valid
    if (context.mounted) {
      Navigator.of(context).pop();
    }
    AppLogger.error('Failed to load stores: $e');
    
    // Check context before showing error dialog
    if (context.mounted) {
      _showErrorDialog(context, 'Error', 'Failed to load stores: $e');
    }
  }
}

void _showStoreSelectionDialog(BuildContext context, WidgetRef ref,
    BusinessInventory businessInventory, List<Store> stores) {
  Store? selectedStore;
  final quantityController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Allocate to Store'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product: ${businessInventory.productName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                  'Available Quantity: ${businessInventory.availableQuantity}'),
              const SizedBox(height: 16),

              // Store Selection
              DropdownButtonFormField<Store>(
                value: selectedStore,
                decoration: const InputDecoration(
                  labelText: 'Select Store',
                  border: OutlineInputBorder(),
                ),
                items: stores
                    .map((store) => DropdownMenuItem(
                          value: store,
                          child: Text(store.name),
                        ))
                    .toList(),
                onChanged: (store) {
                  setState(() {
                    selectedStore = store;
                  });
                },
                validator: (value) =>
                    value == null ? 'Please select a store' : null,
              ),
              const SizedBox(height: 16),

              // Quantity Input
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity to Allocate',
                  border: OutlineInputBorder(),
                  suffixText: 'items',
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid quantity';
                  }
                  if (quantity > businessInventory.availableQuantity) {
                    return 'Quantity exceeds available (${businessInventory.availableQuantity})';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate() && selectedStore != null) {
                final quantity = int.parse(quantityController.text);

                AppLogger.info(
                    'User clicked Allocate button. Store: ${selectedStore!.name}, Quantity: $quantity');

                // Close the selection dialog first
                Navigator.of(context).pop();

                // Perform allocation with proper context management
                try {
                  await _performAllocation(context, ref, businessInventory,
                      selectedStore!, quantity);
                } catch (e) {
                  AppLogger.error('Error in allocation flow: $e');
                  if (context.mounted) {
                    _showErrorDialog(
                        context, 'Error', 'Failed to start allocation: $e');
                  }
                }
              } else {
                AppLogger.warning(
                    'Form validation failed or no store selected');
              }
            },
            child: const Text('Allocate'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _performAllocation(BuildContext context, WidgetRef ref,
    BusinessInventory businessInventory, Store store, int quantity) async {
  // Keep track of whether we've shown the loading dialog
  bool isLoadingDialogShown = false;

  // Add a safety timer to prevent infinite loading
  Timer? safetyTimer;

  try {
    // Wait a bit to ensure previous dialog is closed
    await Future.delayed(const Duration(milliseconds: 200));

    // Show loading dialog
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Allocating inventory...'),
            ],
          ),
        ),
      );
      isLoadingDialogShown = true;

      // Safety timer to close loading dialog after 60 seconds
      safetyTimer = Timer(const Duration(seconds: 60), () {
        if (isLoadingDialogShown && context.mounted) {
          Navigator.of(context).pop();
          isLoadingDialogShown = false;
          AppLogger.error(
              'Allocation operation timed out - forced dialog close');
          _showErrorDialog(
              context, 'Timeout', 'Operation took too long. Please try again.');
        }
      });
    }

    // Get allocation service
    final allocationService = ref.read(inventoryAllocationServiceProvider);

    // Get business context for required fields
    final business = ref.read(businessContextProvider);
    if (business == null) {
      throw Exception('No business context available');
    }

    // Validate business context
    if (businessInventory.businessId.isEmpty) {
      throw Exception('Invalid business context');
    }

    if (store.id.isEmpty || store.name.isEmpty) {
      throw Exception('Invalid store information');
    }

    AppLogger.info(
        'Allocation context - Business: ${businessInventory.businessId}, Store: ${store.id}, Available: ${businessInventory.availableQuantity}');

    // Create allocation item
    final allocationItem = InventoryAllocationItem(
      businessInventoryId: businessInventory.id,
      quantity: quantity,
      minimumQuantity: 1, // Default minimum quantity
    );

    // Pre-validate the allocation request
    final validationResult =
        await allocationService.validateInventoryAllocation(
      businessId: businessInventory.businessId,
      items: [allocationItem],
    );

    if (!validationResult.isValid) {
      final errorMessage = validationResult.invalidItems.values.first;
      throw Exception('Validation failed: $errorMessage');
    }

    AppLogger.info('Validation passed, proceeding with allocation');

    AppLogger.info(
        'Starting allocation: ${businessInventory.productName} -> ${store.name}, quantity: $quantity');

    // Log allocation details for debugging
    AppLogger.info(
        'Allocation details: businessInventoryId=${businessInventory.id}, storeId=${store.id}, businessId=${businessInventory.businessId}');

    // Perform allocation with timeout
    final result = await allocationService.allocateInventoryToStore(
      businessId: businessInventory.businessId,
      businessName: business.name,
      vendorId: business.ownerId,
      storeId: store.id,
      storeName: store.name,
      items: [allocationItem],
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        AppLogger.error('Allocation operation timed out after 30 seconds');
        throw Exception('Operation timed out. Please try again.');
      },
    );

    // Cancel safety timer
    safetyTimer?.cancel();

    // Close loading dialog
    if (isLoadingDialogShown && context.mounted) {
      Navigator.of(context).pop();
      isLoadingDialogShown = false;
    }

    AppLogger.info('Allocation completed, result success: ${result.success}');

    if (result.success) {
      // Add small delay before showing success dialog
      await Future.delayed(const Duration(milliseconds: 100));

      // Show success message
      if (context.mounted) {
        _showSuccessDialog(
            context, 'Allocation Successful', result.summaryMessage);
      }

      // Refresh the business inventory data
      final _ =
          ref.refresh(businessInventoryDetailProvider(businessInventory.id));

      AppLogger.info('Successfully allocated $quantity items to ${store.name}');
    } else {
      // Add small delay before showing error dialog
      await Future.delayed(const Duration(milliseconds: 100));

      // Show error message
      if (context.mounted) {
        _showErrorDialog(context, 'Allocation Failed', result.summaryMessage);
      }
      AppLogger.error('Allocation failed: ${result.summaryMessage}');
    }
  } catch (e) {
    // Cancel safety timer
    safetyTimer?.cancel();

    // Close loading dialog if still open
    if (isLoadingDialogShown && context.mounted) {
      Navigator.of(context).pop();
      isLoadingDialogShown = false;
    }

    AppLogger.error('Exception during allocation: $e');

    // Add small delay before showing error dialog
    await Future.delayed(const Duration(milliseconds: 100));

    if (context.mounted) {
      _showErrorDialog(context, 'Error', 'Failed to allocate inventory: $e');
    }
  }
}

void _showAddQuantityDialog(
    BuildContext context, WidgetRef ref, BusinessInventory businessInventory) {
  final quantityController = TextEditingController();
  final costPriceController = TextEditingController(
    text: businessInventory.costPrice.toStringAsFixed(2),
  );
  final sellingPriceController = TextEditingController(
    text: businessInventory.sellingPrice.toStringAsFixed(2),
  );
  final notesController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Add Quantity'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Product: ${businessInventory.productName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Current Total: ${businessInventory.totalQuantity}'),
              Text('Available: ${businessInventory.availableQuantity}'),
              const SizedBox(height: 16),
              
              // Quantity to add
              TextFormField(
                controller: quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity to Add *',
                  hintText: 'Enter quantity',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter quantity';
                  }
                  final quantity = int.tryParse(value);
                  if (quantity == null || quantity <= 0) {
                    return 'Please enter a valid quantity';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              
              // Cost price
              TextFormField(
                controller: costPriceController,
                decoration: const InputDecoration(
                  labelText: 'Cost Price *',
                  hintText: 'Enter cost price',
                  border: OutlineInputBorder(),
                  prefixText: 'KSh ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter cost price';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Please enter a valid cost price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              
              // Selling price
              TextFormField(
                controller: sellingPriceController,
                decoration: const InputDecoration(
                  labelText: 'Selling Price',
                  hintText: 'Enter selling price',
                  border: OutlineInputBorder(),
                  prefixText: 'KSh ',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return 'Please enter a valid selling price';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              
              // Notes
              TextFormField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                  hintText: 'Enter any notes about this restock',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (formKey.currentState!.validate()) {
              Navigator.pop(context);
              await _performAddQuantity(
                context,
                ref,
                businessInventory,
                int.parse(quantityController.text),
                double.parse(costPriceController.text),
                sellingPriceController.text.isNotEmpty 
                    ? double.parse(sellingPriceController.text) 
                    : null,
                notesController.text.isNotEmpty ? notesController.text : null,
              );
            }
          },
          child: const Text('Add Quantity'),
        ),
      ],
    ),
  );
}

Future<void> _performAddQuantity(
  BuildContext context,
  WidgetRef ref,
  BusinessInventory businessInventory,
  int quantityToAdd,
  double costPrice,
  double? sellingPrice,
  String? notes,
) async {
  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Adding quantity...'),
        ],
      ),
    ),
  );

  try {
    final businessInventoryService = ref.read(businessInventoryServiceProvider);
    
    final success = await businessInventoryService.addQuantityToInventory(
      businessInventoryId: businessInventory.id,
      businessId: businessInventory.businessId,
      quantityToAdd: quantityToAdd,
      costPrice: costPrice,
      sellingPrice: sellingPrice,
      notes: notes,
    );

    // Close loading dialog
    if (context.mounted) {
      Navigator.pop(context);
    }

    if (success) {
      // Refresh the business inventory data
      final _ = ref.refresh(businessInventoryDetailProvider(businessInventory.id));
      
      // Show success message
      if (context.mounted) {
        _showSuccessDialog(
          context,
          'Quantity Added Successfully',
          'Added $quantityToAdd items to ${businessInventory.productName}.\n'
          'New total quantity: ${businessInventory.totalQuantity + quantityToAdd}',
        );
      }
      
      AppLogger.info('Successfully added $quantityToAdd quantity to ${businessInventory.productName}');
    } else {
      if (context.mounted) {
        _showErrorDialog(
          context,
          'Add Quantity Failed',
          'Failed to add quantity to inventory. Please try again.',
        );
      }
      AppLogger.error('Failed to add quantity to inventory');
    }
  } catch (e) {
    // Close loading dialog
    if (context.mounted) {
      Navigator.pop(context);
    }
    
    // Show error message
    if (context.mounted) {
      _showErrorDialog(
        context,
        'Add Quantity Failed',
        'An error occurred: ${e.toString()}',
      );
    }
    AppLogger.error('Error adding quantity to inventory: $e');
  }
}

Future<void> _performEditDetails(
  BuildContext context,
  WidgetRef ref,
  BusinessInventory businessInventory,
  String productName,
  String category,
  double costPrice,
  double sellingPrice,
) async {
  // Show loading dialog
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(),
          SizedBox(width: 16),
          Text('Updating inventory details...'),
        ],
      ),
    ),
  );

  try {
    final businessInventoryService = ref.read(businessInventoryServiceProvider);
    
    // Prepare update data
    final updateData = <String, dynamic>{
      'productName': productName,
      'category': category,
      'costPrice': costPrice,
      'sellingPrice': sellingPrice,
      'totalValue': businessInventory.totalQuantity * costPrice, // Recalculate total value
    };
    
    await businessInventoryService.updateBusinessInventory(
      businessInventoryId: businessInventory.id,
      updateData: updateData,
      changeReason: 'Manual inventory details update',
    );

    // Close loading dialog
    if (context.mounted) {
      Navigator.pop(context);
    }

    // Refresh the business inventory data
    final _ = ref.refresh(businessInventoryDetailProvider(businessInventory.id));
    
    // Show success message
    if (context.mounted) {
      _showSuccessDialog(
        context,
        'Details Updated Successfully',
        'Inventory details for ${productName} have been updated successfully.',
      );
    }
    
    AppLogger.info('Successfully updated inventory details for ${businessInventory.productName}');
  } catch (e) {
    // Close loading dialog
    if (context.mounted) {
      Navigator.pop(context);
    }
    
    // Show error message
    if (context.mounted) {
      _showErrorDialog(
        context,
        'Update Failed',
        'Failed to update inventory details: ${e.toString()}',
      );
    }
    AppLogger.error('Error updating inventory details: $e');
  }
}

void _showEditDetailsDialog(
    BuildContext context, WidgetRef ref, BusinessInventory businessInventory) {
  final productNameController = TextEditingController(text: businessInventory.productName);
  final categoryController = TextEditingController(text: businessInventory.category);
  final costPriceController = TextEditingController(
    text: businessInventory.costPrice.toStringAsFixed(2),
  );
  final sellingPriceController = TextEditingController(
    text: businessInventory.sellingPrice.toStringAsFixed(2),
  );
  final formKey = GlobalKey<FormState>();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Edit Inventory Details'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit details for inventory item',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Product Name
                TextFormField(
                  controller: productNameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name *',
                    hintText: 'Enter product name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter product name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                
                // Category
                TextFormField(
                  controller: categoryController,
                  decoration: const InputDecoration(
                    labelText: 'Category *',
                    hintText: 'Enter category',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                
                // Cost Price
                TextFormField(
                  controller: costPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Cost Price *',
                    hintText: 'Enter cost price',
                    border: OutlineInputBorder(),
                    prefixText: 'KSh ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter cost price';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return 'Please enter a valid cost price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                
                // Selling Price
                TextFormField(
                  controller: sellingPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Selling Price *',
                    hintText: 'Enter selling price',
                    border: OutlineInputBorder(),
                    prefixText: 'KSh ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter selling price';
                    }
                    final price = double.tryParse(value);
                    if (price == null || price <= 0) {
                      return 'Please enter a valid selling price';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Current quantities info (read-only)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Quantities (Read-only)',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Total Quantity: ${businessInventory.totalQuantity}'),
                      Text('Available Quantity: ${businessInventory.availableQuantity}'),
                      Text('Allocated Quantity: ${businessInventory.totalQuantity - businessInventory.availableQuantity}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (formKey.currentState!.validate()) {
              // Check if any changes were made
              final hasChanges = productNameController.text.trim() != businessInventory.productName ||
                                categoryController.text.trim() != businessInventory.category ||
                                double.parse(costPriceController.text) != businessInventory.costPrice ||
                                double.parse(sellingPriceController.text) != businessInventory.sellingPrice;
              
              if (!hasChanges) {
                Navigator.pop(context);
                _showInfoDialog(context, 'No Changes', 'No changes were made to the inventory details.');
                return;
              }
              
              Navigator.pop(context);
              await _performEditDetails(
                context,
                ref,
                businessInventory,
                productNameController.text.trim(),
                categoryController.text.trim(),
                double.parse(costPriceController.text),
                double.parse(sellingPriceController.text),
              );
            }
          },
          child: const Text('Save Changes'),
        ),
      ],
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

void _showSuccessDialog(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void _showErrorDialog(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

void _showInfoDialog(BuildContext context, String title, String message) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.info, color: Colors.blue),
          const SizedBox(width: 8),
          Text(title),
        ],
      ),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<void> _navigateToStoreInventoryDetail(
    BuildContext context,
    WidgetRef ref,
    StoreDistribution storeDistribution,
    String businessInventoryId) async {
  try {
    // Get the business inventory to access business ID and product ID
    final businessInventoryAsync = await ref
        .read(businessInventoryDetailProvider(businessInventoryId).future);

    if (businessInventoryAsync == null) {
      AppLogger.error('Business inventory not found');
      return;
    }

    // Get store inventory service
    final storeInventoryService = StoreInventoryService();

    // Find the store inventory record for this product and store
    final storeInventory =
        await storeInventoryService.getStoreInventoryByProductId(
      businessId: businessInventoryAsync.businessId,
      storeId: storeDistribution.storeId,
      productId: businessInventoryAsync.productId,
    );

    if (storeInventory == null) {
      AppLogger.warning(
          'Store inventory not found for product ${businessInventoryAsync.productName} in store ${storeDistribution.storeName}');
      // Show message that store inventory details are not available
      if (context.mounted) {
        _showErrorDialog(context, 'Not Available',
            'Store inventory details are not available for this item in ${storeDistribution.storeName}');
      }
      return;
    }

    // Navigate to store inventory detail screen
    if (context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => StoreInventoryDetailScreen(
            businessId: businessInventoryAsync.businessId,
            storeId: storeDistribution.storeId,
            inventoryId: storeInventory.id,
          ),
        ),
      );
    }
  } catch (e) {
    AppLogger.error('Error navigating to store inventory detail: $e');
    if (context.mounted) {
      _showErrorDialog(
          context, 'Error', 'Failed to load store inventory details: $e');
    }
  }
}

String _formatDateTime(DateTime dateTime) {
  return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
}
