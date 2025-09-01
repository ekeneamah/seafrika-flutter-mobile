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
import 'package:provider/provider.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/services/inventory_service.dart';
import 'package:vendor_app/widgets/error_view.dart' as error;
import 'package:vendor_app/widgets/loading_view.dart';

class InventoryDashboardScreen extends StatefulWidget {
  const InventoryDashboardScreen({super.key});

  @override
  State<InventoryDashboardScreen> createState() =>
      _InventoryDashboardScreenState();
}

class _InventoryDashboardScreenState extends State<InventoryDashboardScreen> {
  bool _isLoading = false;
  Map<String, dynamic>? _analytics;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    try {
      final inventoryService = context.read<InventoryService>();
      _analytics = await inventoryService.getInventoryAnalytics();
      setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load inventory analytics')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: LoadingView(),
      );
    }

    if (_analytics == null) {
      return Scaffold(
        body: error.ErrorView(
          message: 'Failed to load analytics',
          onRetry: _loadAnalytics,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () => NavigationService.navigateToInventoryList(),
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
      title: Text(item['productName']),
      subtitle: Text(
        'Current: ${item['quantity']} • Minimum: ${item['minimumQuantity']}',
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () => NavigationService.navigateToEditInventory(item['id']),
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
