/// A dashboard screen that provides an overview of inventory management.
///
/// This screen displays:
/// - Key metrics (total items, low stock items, total value)
/// - Low stock alerts with quick access to edit
/// - Quick action buttons for common tasks
///
/// Features:
/// - Real-time analytics
/// - Pull-to-refresh functionality
/// - Quick navigation to inventory list
/// - Direct access to create new inventory items
/// - Low stock monitoring and management

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/providers/service_providers.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/models/business.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';
import 'package:vendor_app/utils/business_validation_helper.dart';

class InventoryDashboardScreen extends ConsumerStatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  ConsumerState<InventoryDashboardScreen> createState() =>
      _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends ConsumerState<InventoryDashboardScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _analytics;

  @override
  void initState() {
    super.initState();
    _validateBusinessSelection();
    _loadAnalytics();
  }

  /// Validates that business is selected, redirects if not
  Future<void> _validateBusinessSelection() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final businessContext = ref.read(businessContextProvider);
      if (businessContext == null) {
        await BusinessValidationHelper.validateBusinessSelection(context);
        // Reload analytics after business selection
        if (mounted) {
          _loadAnalytics();
        }
      }
    });
  }

  Future<void> _loadAnalytics() async {
    final businessContext = ref.read(businessContextProvider);
    if (businessContext == null) {
      // Business not selected, show error or redirect
      setState(() {
        _isLoading = false;
        _analytics = null;
      });
      return;
    }

    setState(() => _isLoading = true);
    try {
      final inventoryService = ref.read(inventoryServiceProvider);
      // The inventory service is already scoped to the business owner (vendorId)
      _analytics = await inventoryService.getInventoryAnalytics();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load inventory analytics: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Navigate to direct add from media functionality
  void _navigateToDirectAddFromMedia() {
    final businessContext = ref.read(businessContextProvider);
    if (businessContext == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a business first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // TODO: Implement navigation to media picker for direct inventory add
    // This could integrate with the DirectSellService's addMediaToStoreDirectly method
    // Pass businessContext.id, businessContext.name, etc.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Direct media add for ${businessContext.name} coming soon!'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  /// Navigate to media gallery for inventory management
  void _navigateToMediaGallery() {
    final businessContext = ref.read(businessContextProvider);
    if (businessContext == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a business first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // TODO: Implement navigation to media gallery screen
    // Show media for this specific business
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Media gallery for ${businessContext.name} coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  /// Format storage size from bytes to human readable format
  String _formatStorageSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
  }

  @override
  Widget build(BuildContext context) {
    // Listen for business context changes and reload analytics
    ref.listen<Business?>(businessContextProvider, (previous, current) {
      if (previous != current && current != null) {
        // Business changed, reload analytics
        _loadAnalytics();
      }
    });

    if (_isLoading) {
      return const Scaffold(
        body: LoadingView(),
      );
    }

    if (_analytics == null) {
      final businessContext = ref.watch(businessContextProvider);
      if (businessContext == null) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Inventory Dashboard'),
            actions: [
              IconButton(
                icon: const Icon(Icons.business),
                onPressed: () => BusinessValidationHelper.validateBusinessSelection(context),
                tooltip: 'Select Business',
              ),
            ],
          ),
          body: Center(
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
                  'Please select a business to view inventory dashboard.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    await BusinessValidationHelper.validateBusinessSelection(context);
                    if (mounted) _loadAnalytics();
                  },
                  icon: const Icon(Icons.business),
                  label: const Text('Select Business'),
                ),
              ],
            ),
          ),
        );
      }
      
      return Scaffold(
        body: error.ErrorView(
          message: 'Failed to load analytics',
          onRetry: _loadAnalytics,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inventory Dashboard'),
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
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => NavigationService.navigateToInventoryList(),
            tooltip: 'View All Inventory',
          ),
          Consumer(
            builder: (context, ref, child) {
              final businessContext = ref.watch(businessContextProvider);
              return IconButton(
                icon: const Icon(Icons.business),
                onPressed: businessContext == null
                    ? () => BusinessValidationHelper.validateBusinessSelection(context)
                    : null,
                tooltip: businessContext == null ? 'Select Business' : businessContext.name,
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAnalytics,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildOverviewCard(),
            const SizedBox(height: 16),
            _buildLowStockCard(),
            const SizedBox(height: 16),
            _buildQuickActionsCard(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => NavigationService.navigateToCreateInventory(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              'Total Items',
              _analytics!['totalItems'].toString(),
            ),
            _buildMetricRow(
              'Low Stock Items',
              _analytics!['lowStockItems'].toString(),
            ),
            _buildMetricRow(
              'Total Value',
              '\$${_analytics!['totalValue'].toStringAsFixed(2)}',
            ),
            _buildMetricRow(
              'Items with Images',
              _analytics!['itemsWithImages']?.toString() ?? 'N/A',
            ),
            _buildMetricRow(
              'Storage Used',
              _formatStorageSize(_analytics!['totalStorageUsed'] ?? 0),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockCard() {
    final lowStockItems = _analytics!['lowStockItemsList'] as List<dynamic>;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Low Stock Items',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () => NavigationService.navigateToInventoryList(),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (lowStockItems.isEmpty)
              const Center(
                child: Text('No low stock items'),
              )
            else
              ...lowStockItems.map((item) => _buildLowStockItem(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionButton(
                  icon: Icons.add,
                  label: 'Add Item',
                  onTap: () => NavigationService.navigateToCreateInventory(),
                ),
                _buildActionButton(
                  icon: Icons.add_a_photo,
                  label: 'Add from Media',
                  onTap: () => _navigateToDirectAddFromMedia(),
                ),
                _buildActionButton(
                  icon: Icons.list,
                  label: 'View All',
                  onTap: () => NavigationService.navigateToInventoryList(),
                ),
                _buildActionButton(
                  icon: Icons.warning,
                  label: 'Low Stock',
                  onTap: () => NavigationService.navigateToInventoryList(),
                ),
                _buildActionButton(
                  icon: Icons.analytics,
                  label: 'Analytics',
                  onTap: () => NavigationService.navigateToInventoryList(),
                ),
                _buildActionButton(
                  icon: Icons.photo_library,
                  label: 'Media Gallery',
                  onTap: () => _navigateToMediaGallery(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
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
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockItem(Map<String, dynamic> item) {
    return ListTile(
      leading: item['productImage'] != null && item['productImage'].isNotEmpty
          ? CircleAvatar(
              backgroundImage: NetworkImage(item['productImage']),
              backgroundColor: Colors.grey[200],
            )
          : CircleAvatar(
              backgroundColor: Colors.grey[200],
              child: const Icon(Icons.inventory, color: Colors.grey),
            ),
      title: Text(item['productName']),
      subtitle: Text(
        'Current: ${item['quantity']} • Minimum: ${item['minimumQuantity']}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add_shopping_cart, color: Colors.green),
            onPressed: () => _quickRestock(item),
            tooltip: 'Quick Restock',
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => NavigationService.navigateToEditInventory(item['id']),
            tooltip: 'Edit',
          ),
        ],
      ),
    );
  }

  /// Quick restock functionality
  void _quickRestock(Map<String, dynamic> item) {
    final businessContext = ref.read(businessContextProvider);
    if (businessContext == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business context required for restocking'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // TODO: Implement quick restock dialog with business context
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Quick restock for ${item['productName']} in ${businessContext.name} coming soon!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
