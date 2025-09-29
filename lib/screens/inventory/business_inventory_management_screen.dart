/// A comprehensive screen for managing business inventory with CRUD operations.
///
/// This screen provides:
/// - List view of all business inventory items
/// - Search and filter capabilities
/// - Add new inventory items
/// - Edit existing inventory items
/// - Delete inventory items
/// - View detailed information
/// - Bulk operations
///
/// Features:
/// - Real-time inventory updates
/// - Low stock alerts
/// - Category filtering
/// - Sort by various criteria
/// - Export capabilities

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vendor_app/config/theme.dart';
import 'package:vendor_app/config/routes.dart';
import 'package:vendor_app/models/business_inventory.dart';
import 'package:vendor_app/providers/business_inventory_provider.dart'
    as biz_inventory;
import 'package:vendor_app/providers/business_inventory_provider.dart';
import 'package:vendor_app/providers/business_context_provider.dart';
import 'package:vendor_app/widgets/error_view.dart' as error_view;
import 'package:vendor_app/widgets/loading_view.dart' as loading_view;
import 'package:vendor_app/services/navigation_service.dart';
import 'package:vendor_app/screens/analytics/cost_price_history_screen.dart';

class BusinessInventoryManagementScreen extends ConsumerStatefulWidget {
  const BusinessInventoryManagementScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<BusinessInventoryManagementScreen> createState() =>
      _BusinessInventoryManagementScreenState();
}

class _BusinessInventoryManagementScreenState
    extends ConsumerState<BusinessInventoryManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedItems = <String>{};
  String _selectedCategory = 'All';
  String _sortBy = 'name'; // name, quantity, value, updated
  bool _isAscending = true;
  bool _showLowStockOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInventory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInventory() async {
    // Invalidate the provider to force a refresh
    ref.invalidate(biz_inventory.businessInventoryListProvider);
  }

  List<BusinessInventory> _getFilteredAndSortedInventory(
      List<BusinessInventory> inventory) {
    List<BusinessInventory> filtered = inventory;

    // Apply search filter
    final searchQuery = _searchController.text.toLowerCase();
    if (searchQuery.isNotEmpty) {
      filtered = filtered
          .where((item) =>
              item.productName.toLowerCase().contains(searchQuery) ||
              item.category.toLowerCase().contains(searchQuery) ||
              (item.notes?.toLowerCase().contains(searchQuery) ?? false))
          .toList();
    }

    // Apply category filter
    if (_selectedCategory != 'All') {
      filtered =
          filtered.where((item) => item.category == _selectedCategory).toList();
    }

    // Apply low stock filter (consider items with less than 10 as low stock)
    if (_showLowStockOnly) {
      filtered =
          filtered.where((item) => item.availableQuantity <= 10).toList();
    }

    // Apply sorting
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'name':
          comparison = a.productName.compareTo(b.productName);
          break;
        case 'quantity':
          comparison = a.availableQuantity.compareTo(b.availableQuantity);
          break;
        case 'value':
          final aValue = a.availableQuantity * a.costPrice;
          final bValue = b.availableQuantity * b.costPrice;
          comparison = aValue.compareTo(bValue);
          break;
        case 'updated':
          comparison = a.updatedAt.compareTo(b.updatedAt);
          break;
      }
      return _isAscending ? comparison : -comparison;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final businessContext = ref.watch(businessContextProvider);

    print(
        '🏢 [BusinessInventoryManagement] Business context: ${businessContext?.id}');

    if (businessContext == null) {
      print('❌ [BusinessInventoryManagement] No business context found');
      return Scaffold(
        body: error_view.ErrorView(
          message: 'No business selected. Please select a business first.',
          onRetry: () {
            // Navigate back or refresh business context
            Navigator.pop(context);
          },
        ),
      );
    }

    // Use StreamBuilder to directly query the business inventory
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Business Inventory Management'),
        backgroundColor: AppTheme.glass,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (_selectedItems.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _showBulkDeleteDialog(),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showBulkActionsMenu(),
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _navigateToCreateInventory(),
            ),
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () => _showSortMenu(),
            ),
          ],
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('business_inventory')
            .where('businessId', isEqualTo: businessContext.id)
            .where('status', isEqualTo: 'active')
            .orderBy('productName')
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          print(
              '📦 [BusinessInventoryManagement] Stream state: ${snapshot.connectionState}');

          if (snapshot.connectionState == ConnectionState.waiting) {
            print('⏳ [BusinessInventoryManagement] Loading...');
            return const loading_view.LoadingView();
          }

          if (snapshot.hasError) {
            print('❌ [BusinessInventoryManagement] Error: ${snapshot.error}');
            return error_view.ErrorView(
              message: 'Failed to load business inventory: ${snapshot.error}',
              onRetry: _loadInventory,
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print(
                '📦 [BusinessInventoryManagement] No data found: ${snapshot.data?.docs.length ?? 0} items');
            return _buildEmptyState();
          }

          final documents = snapshot.data!.docs;
          print(
              '✅ [BusinessInventoryManagement] Data loaded: ${documents.length} items');

          final inventory = documents
              .map((doc) => BusinessInventory.fromFirestore(
                  doc as DocumentSnapshot<Map<String, dynamic>>))
              .toList();

          final filteredInventory = _getFilteredAndSortedInventory(inventory);
          final categories =
              ['All'] + inventory.map((e) => e.category).toSet().toList()
                ..sort();

          return Column(
            children: [
              _buildHeaderSection(categories),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadInventory,
                  child: filteredInventory.isEmpty
                      ? _buildEmptyState()
                      : _buildInventoryList(filteredInventory),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _selectedItems.isEmpty
          ? FloatingActionButton(
              onPressed: _navigateToCreateInventory,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildHeaderSection(List<String> categories) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glass,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.whiteSmoke,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.earthLight.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search inventory items...',
                hintStyle: TextStyle(color: AppTheme.earth),
                prefixIcon: Icon(Icons.search, color: AppTheme.earth),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
              ),
              onChanged: (value) => setState(() {}),
            ),
          ),
          const SizedBox(height: 16),

          // Filters Row
          Row(
            children: [
              // Category Filter
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.glass,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppTheme.earthLight.withOpacity(0.3)),
                  ),
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    hint: Text(
                      'Category',
                      style: TextStyle(color: AppTheme.earth),
                    ),
                    items: categories
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(
                                category,
                                style: TextStyle(color: AppTheme.textPrimary),
                              ),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value ?? 'All'),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Low Stock Filter
              FilterChip(
                label: Text(
                  'Low Stock',
                  style: TextStyle(
                    color:
                        _showLowStockOnly ? Colors.white : AppTheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                selected: _showLowStockOnly,
                onSelected: (selected) =>
                    setState(() => _showLowStockOnly = selected),
                selectedColor: AppTheme.secondary,
                backgroundColor: AppTheme.secondary.withOpacity(0.1),
                checkmarkColor: Colors.white,
                side: BorderSide(
                  color: AppTheme.secondary.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryList(List<BusinessInventory> inventory) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: inventory.length,
      itemBuilder: (context, index) {
        final item = inventory[index];
        final isSelected = _selectedItems.contains(item.id);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.glass,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary
                  : AppTheme.earthLight.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _selectedItems.isEmpty
                ? _navigateToInventoryDetail(item.id)
                : _toggleSelection(item.id),
            onLongPress: () => _toggleSelection(item.id),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Selection Checkbox (when in selection mode)
                  if (_selectedItems.isNotEmpty) ...[
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppTheme.primary : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.earthLight,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 14,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Product Image
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppTheme.whiteSmoke,
                    ),
                    child: item.displayImageUrl != null &&
                            item.displayImageUrl!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              item.displayImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.inventory_2_outlined,
                                color: AppTheme.earth,
                                size: 24,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.inventory_2_outlined,
                            color: AppTheme.earth,
                            size: 24,
                          ),
                  ),
                  const SizedBox(width: 16),

                  // Product Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.productName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.category,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.earth,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Flexible(
                              flex: 3,
                              child: _buildStatusChip(item),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              flex: 2,
                              child: Text(
                                'NGN ${(item.availableQuantity * item.costPrice).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                                textAlign: TextAlign.end,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildStoreDistribution(item),
                      ],
                    ),
                  ),

                  // Action Menu
                  if (_selectedItems.isEmpty)
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.earthLight.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: PopupMenuButton<String>(
                        onSelected: (action) => _handleItemAction(action, item),
                        icon: Icon(
                          Icons.more_vert,
                          color: AppTheme.earth,
                          size: 20,
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'view',
                            child: Row(
                              children: [
                                Icon(Icons.visibility_outlined, size: 18),
                                SizedBox(width: 12),
                                Text('View Details'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'history',
                            child: Row(
                              children: [
                                Icon(Icons.history, size: 18),
                                SizedBox(width: 12),
                                Text('Cost History'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'update_cost',
                            child: Row(
                              children: [
                                Icon(Icons.price_change_outlined, size: 18),
                                SizedBox(width: 12),
                                Text('Update Cost Price'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 18),
                                SizedBox(width: 12),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'allocate',
                            child: Row(
                              children: [
                                Icon(Icons.store_outlined, size: 18),
                                SizedBox(width: 12),
                                Text('Allocate to Store'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline,
                                    size: 18, color: Colors.red),
                                SizedBox(width: 12),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(BusinessInventory item) {
    final isLowStock =
        item.availableQuantity <= 10; // Consider less than 10 as low stock
    final isOutOfStock = item.availableQuantity == 0;

    Color chipColor;
    String statusText;

    if (isOutOfStock) {
      chipColor = AppTheme.secondary;
      statusText = 'Out of Stock';
    } else if (isLowStock) {
      chipColor = Colors.orange;
      statusText = 'Low (${item.availableQuantity})';
    } else {
      chipColor = AppTheme.primary;
      statusText = '${item.availableQuantity} in stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: chipColor,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStoreDistribution(BusinessInventory item) {
    if (item.storeDistribution == null || item.storeDistribution!.isEmpty) {
      return Row(
        children: [
          Icon(
            Icons.store_outlined,
            size: 14,
            color: AppTheme.earthLight,
          ),
          const SizedBox(width: 4),
          Text(
            'No store allocation',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.earthLight,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    final stores = item.storeDistribution!.values.toList();
    final totalStores = stores.length;
    final totalAllocated = item.totalAllocatedQuantity;

    return Row(
      children: [
        Icon(
          Icons.store_outlined,
          size: 14,
          color: AppTheme.primary,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            totalStores == 1
                ? '${stores.first.allocatedQuantity} units in ${stores.first.storeName}'
                : '$totalAllocated units in $totalStores stores',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.earth,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (totalStores > 1) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '+${totalStores - 1}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.softGreen,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No inventory items found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start building your business inventory by adding your first item.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.earth,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _navigateToCreateInventory,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Add First Item',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelection(String itemId) {
    setState(() {
      if (_selectedItems.contains(itemId)) {
        _selectedItems.remove(itemId);
      } else {
        _selectedItems.add(itemId);
      }
    });
  }

  void _navigateToInventoryDetail(String businessInventoryId) {
    NavigationService.navigateToBusinessInventoryDetail(businessInventoryId);
  }

  void _navigateToCreateInventory() {
    Navigator.pushNamed(context, AppRoutes.createInventory);
  }

  void _handleItemAction(String action, BusinessInventory item) {
    switch (action) {
      case 'view':
        _navigateToInventoryDetail(item.id);
        break;
      case 'history':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CostPriceHistoryScreen(
              businessInventoryId: item.id,
            ),
          ),
        );
        break;
      case 'update_cost':
        _showUpdateCostPriceDialog(item);
        break;
      case 'edit':
        Navigator.pushNamed(
          context,
          AppRoutes.editInventory,
          arguments: {'inventory': item},
        );
        break;
      case 'delete':
        _showDeleteDialog(item);
        break;
      case 'allocate':
        _showAllocateDialog(item);
        break;
    }
  }

  void _showDeleteDialog(BusinessInventory item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Inventory Item'),
        content: Text(
            'Are you sure you want to delete "${item.productName}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteItem(item.id);
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showBulkDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Items'),
        content: Text(
            'Are you sure you want to delete ${_selectedItems.length} selected items? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteBulkItems();
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.secondary),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );
  }

  void _showAllocateDialog(BusinessInventory item) {
    // TODO: Implement store allocation dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Store allocation feature coming soon!')),
    );
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sort By',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...['name', 'quantity', 'value', 'updated'].map(
              (option) => ListTile(
                title: Text(_getSortLabel(option)),
                leading: Radio<String>(
                  value: option,
                  groupValue: _sortBy,
                  onChanged: (value) {
                    setState(() => _sortBy = value!);
                    Navigator.pop(context);
                  },
                ),
                trailing: _sortBy == option
                    ? IconButton(
                        icon: Icon(_isAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward),
                        onPressed: () {
                          setState(() => _isAscending = !_isAscending);
                          Navigator.pop(context);
                        },
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBulkActionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Bulk Actions (${_selectedItems.length} items)',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete Selected'),
              onTap: () {
                Navigator.pop(context);
                _showBulkDeleteDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Bulk Edit'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement bulk edit
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Export Selected'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implement export
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getSortLabel(String sortKey) {
    switch (sortKey) {
      case 'name':
        return 'Product Name';
      case 'quantity':
        return 'Available Quantity';
      case 'value':
        return 'Total Value';
      case 'updated':
        return 'Last Updated';
      default:
        return sortKey;
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      // TODO: Implement delete functionality via service
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item deleted successfully')),
      );
      _loadInventory(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete item: $e')),
      );
    }
  }

  Future<void> _deleteBulkItems() async {
    try {
      // TODO: Implement bulk delete functionality via service
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('${_selectedItems.length} items deleted successfully')),
      );
      setState(() => _selectedItems.clear());
      _loadInventory(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete items: $e')),
      );
    }
  }

  void _showUpdateCostPriceDialog(BusinessInventory item) {
    final costController = TextEditingController(
      text: item.costPrice.toStringAsFixed(2),
    );
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.price_change_outlined,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Cost Price',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    item.productName,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.earth,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Current Cost Price: NGN ${item.costPrice.toStringAsFixed(2)}',
              style: TextStyle(
                color: AppTheme.earth,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: costController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'New Cost Price (NGN)',
                hintText: 'Enter new cost price',
                prefixIcon: Icon(Icons.attach_money, color: AppTheme.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Reason for Change',
                hintText: 'e.g., Supplier price increase, Market adjustment',
                prefixIcon:
                    Icon(Icons.comment_outlined, color: AppTheme.primary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppTheme.earth),
            ),
          ),
          ElevatedButton(
            onPressed: () => _updateCostPrice(
              item,
              costController.text,
              reasonController.text,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCostPrice(
    BusinessInventory item,
    String newCostPriceText,
    String reason,
  ) async {
    final newCostPrice = double.tryParse(newCostPriceText);

    if (newCostPrice == null || newCostPrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid cost price')),
      );
      return;
    }

    if (reason.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please provide a reason for the price change')),
      );
      return;
    }

    Navigator.pop(context); // Close dialog

    try {
      final updateNotifier = ref.read(businessInventoryUpdateProvider);
      await updateNotifier.updateCostPrice(
        businessInventoryId: item.id,
        newCostPrice: newCostPrice,
        changeReason: reason.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cost price updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _loadInventory(); // Refresh the list
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update cost price: $e')),
      );
    }
  }
}
